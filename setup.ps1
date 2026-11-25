#requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateNotNullOrEmpty()]
    [string[]]$Target = @('all'),
    [switch]$SkipPackages,
    [switch]$SkipExtensions,
    [switch]$UpdateTools,
    [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$targets = @($Target -split ',' | ForEach-Object { $_.Trim() })
$validTargets = @('all', 'tools', 'powershell', 'psmux', 'vscodium', 'terminal')
foreach ($name in $targets) {
    if ($name -notin $validTargets) {
        throw "Invalid setup target '$name'. Valid targets: $($validTargets -join ', ')."
    }
}
$targetList = $targets -join ','

$repoRoot = $PSScriptRoot
$configRoot = Join-Path $repoRoot 'configs'
$toolsRoot = Join-Path $env:LOCALAPPDATA 'dotfiles'
$toolBin = Join-Path $toolsRoot 'bin'
$statePath = Join-Path $toolsRoot 'tools.json'
$backupRoot = Join-Path $env:USERPROFILE ('.dotfiles-backup/' + (Get-Date -Format 'yyyyMMdd-HHmmss-ffff'))
$utf8 = New-Object System.Text.UTF8Encoding($false)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if ($DryRun) {
    Write-Output "Target: $targetList; portable tools: $toolsRoot"
    Write-Output 'powershell: PowerShell 7, Starship, zoxide, fzf; managed profile loader (existing profile retained)'
    Write-Output 'psmux: native psmux/pmux/tmux, ~/.psmux.conf; existing sessions left running'
    Write-Output 'vscodium: current portable config, extension manifest, bundled Dalbit theme; backup changed files'
    Write-Output 'terminal: named Dalbit PowerShell profile in a Windows Terminal fragment'
    return
}

New-Item -ItemType Directory -Path $toolBin -Force | Out-Null
$script:toolState = @{}
if (Test-Path -LiteralPath $statePath) {
    # Save-ToolState writes UTF-8 without a BOM; PS 5.1 otherwise uses ANSI.
    $saved = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($property in $saved.PSObject.Properties) { $script:toolState[$property.Name] = $property.Value }
}

function Save-ToolState {
    [IO.File]::WriteAllText($statePath, ($script:toolState | ConvertTo-Json -Depth 10), $utf8)
}
function Write-ToolShims {
    param([string]$Name, [string]$BinaryPath, [string[]]$Aliases)
    foreach ($commandName in (@($Name) + $Aliases)) {
        $nativeAlias = Join-Path (Split-Path -Parent $BinaryPath) "$commandName.exe"
        $launch = if (Test-Path -LiteralPath $nativeAlias) { $nativeAlias } else { $BinaryPath }
        $shim = '@echo off' + "`r`n" + '@"' + $launch + '" %*' + "`r`n"
        [IO.File]::WriteAllText((Join-Path $toolBin "$commandName.cmd"), $shim, [Text.Encoding]::ASCII)
    }
}
function Install-ReleaseTool {
    param([string]$Name, [string]$Repository, [string]$AssetPattern, [string]$Executable, [string[]]$Aliases = @())
    if (-not $UpdateTools -and $script:toolState[$Name] -and (Test-Path -LiteralPath $script:toolState[$Name])) {
        Write-ToolShims $Name $script:toolState[$Name] $Aliases
        return $script:toolState[$Name]
    }
    if ($SkipPackages) {
        $found = Get-Command $Executable -ErrorAction SilentlyContinue
        if (-not $found) { throw "Missing $Executable. Rerun without -SkipPackages." }
        $script:toolState[$Name] = $found.Source
        Save-ToolState
        return $found.Source
    }
    $headers = @{ 'User-Agent' = 'dotfiles-windows-setup' }
    $release = Invoke-RestMethod "https://api.github.com/repos/$Repository/releases/latest" -Headers $headers
    $asset = @($release.assets | Where-Object { $_.name -like $AssetPattern })
    if ($asset.Count -ne 1) { throw "Expected one $AssetPattern asset in $Repository; found $($asset.Count)." }
    $asset = $asset[0]
    $cache = Join-Path $toolsRoot 'cache'
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
    $archive = Join-Path $cache $asset.name
    if (-not (Test-Path -LiteralPath $archive)) {
        Write-Host "[+] Downloading $($asset.name)"
        Invoke-WebRequest $asset.browser_download_url -OutFile $archive -UseBasicParsing
    }
    if ($asset.digest -like 'sha256:*') {
        $actualHash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        if ($actualHash -ne $asset.digest.Substring(7)) { throw "Checksum mismatch: $archive" }
    }
    $destination = Join-Path $toolsRoot "packages/$Name/$($release.tag_name)"
    New-Item -ItemType Directory -Path $destination -Force | Out-Null
    if ($archive.EndsWith('.zip')) {
        Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force
        $binary = Get-ChildItem -LiteralPath $destination -Filter $Executable -File -Recurse | Select-Object -First 1
        if (-not $binary) { throw "Missing $Executable in $archive" }
        $binaryPath = $binary.FullName
    } else {
        $binaryPath = Join-Path $destination $Executable
        Copy-Item -LiteralPath $archive -Destination $binaryPath -Force
    }
    # Keep each executable with its bundled DLLs/runtime; shims expose it on PATH.
    Write-ToolShims $Name $binaryPath $Aliases
    $script:toolState[$Name] = $binaryPath
    Save-ToolState
    return $binaryPath
}
function Set-UserPath {
    param([string[]]$Directories)
    $savedPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($savedPath -split ';' | Where-Object { $_ })
    foreach ($directory in $Directories) {
        if ($parts -notcontains $directory) { $parts += $directory }
        if (($env:PATH -split ';') -notcontains $directory) { $env:PATH = "$directory;$env:PATH" }
    }
    $newPath = $parts -join ';'
    if ($newPath -ne $savedPath) { [Environment]::SetEnvironmentVariable('Path', $newPath, 'User') }
}

$arm = $env:PROCESSOR_ARCHITECTURE -eq 'ARM64'
$winArch = if ($arm) { 'arm64' } else { 'x64' }
$rustArch = if ($arm) { 'aarch64' } else { 'x86_64' }
$goArch = if ($arm) { 'arm64' } else { 'amd64' }

# Bootstrap without administrator rights, then use PS7's JSONC/deep JSON support.
$pwshPath = Install-ReleaseTool pwsh PowerShell/PowerShell "PowerShell-*-win-$winArch.zip" pwsh.exe
Set-UserPath @($toolBin, (Split-Path -Parent $pwshPath))
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $forward = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Target', $targetList)
    if ($SkipPackages) { $forward += '-SkipPackages' }
    if ($SkipExtensions) { $forward += '-SkipExtensions' }
    if ($UpdateTools) { $forward += '-UpdateTools' }
    & $pwshPath @forward
    if ($LASTEXITCODE -ne 0) { throw "PowerShell 7 setup exited with $LASTEXITCODE" }
    return
}

function Write-ManagedFile {
    param([string]$Path, [string]$Content)
    if ((Test-Path -LiteralPath $Path) -and [IO.File]::ReadAllText($Path) -ceq $Content) { return }
    if (Test-Path -LiteralPath $Path) {
        # Preserve full relative paths; same-named profile files must not collide.
        $relative = $Path.Substring([IO.Path]::GetPathRoot($Path).Length)
        $backup = Join-Path $backupRoot $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $backup) -Force | Out-Null
        Copy-Item -LiteralPath $Path -Destination $backup
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    [IO.File]::WriteAllText($Path, $Content, $utf8)
}
function Copy-ManagedFile {
    param([string]$Source, [string]$Destination)
    Write-ManagedFile $Destination ([IO.File]::ReadAllText($Source))
}
function ConvertTo-ConfigJson {
    param($Value)
    $json = $Value | ConvertTo-Json -Depth 100
    # ConvertTo-Json uses two spaces; keep the editor's four-space preference.
    return [regex]::Replace($json, '(?m)^ +', { param($match) ' ' * ($match.Length * 2) })
}
function Install-PowerShellConfig {
    $null = Install-ReleaseTool starship starship/starship "starship-$rustArch-pc-windows-msvc.zip" starship.exe
    $null = Install-ReleaseTool zoxide ajeetdsouza/zoxide "zoxide-*-$rustArch-pc-windows-msvc.zip" zoxide.exe
    $null = Install-ReleaseTool fzf junegunn/fzf "fzf-*-windows_$goArch.zip" fzf.exe
    $profileConfig = Join-Path $env:USERPROFILE '.config/powershell/dotfiles-profile.ps1'
    Copy-ManagedFile (Join-Path $configRoot 'powershell/profile.ps1') $profileConfig
    $accent = switch (($env:COMPUTERNAME -split '\.')[0].ToLowerInvariant()) {
        'sivir' { '208' }; 'kayle' { '221' }; 'mundo' { '135' }
        'ashe' { '117' }; 'thyme' { '143' }; default { '10' }
    }
    $promptConfig = [IO.File]::ReadAllText((Join-Path $configRoot 'powershell/starship.toml')).Replace('bold green', "bold $accent")
    Write-ManagedFile (Join-Path $env:USERPROFILE '.config/starship.toml') $promptConfig
    Copy-ManagedFile (Join-Path $configRoot 'mdview/style.css') (Join-Path $env:USERPROFILE '.local/share/mdview/style.css')
    # Use AllHosts so PowerShell in VSCodium and Windows Terminal share the setup.
    $documents = [Environment]::GetFolderPath('MyDocuments')
    $loader = '. "' + $profileConfig + '" # dotfiles managed profile'
    foreach ($directory in @('PowerShell', 'WindowsPowerShell')) {
        $profilePath = Join-Path $documents "$directory/profile.ps1"
        $content = if (Test-Path -LiteralPath $profilePath) { [IO.File]::ReadAllText($profilePath) } else { '' }
        if ($content -notmatch '# dotfiles managed profile') {
            Write-ManagedFile $profilePath ($content.TrimEnd() + "`n" + $loader + "`n")
        }
    }
}
function Install-PsmuxConfig {
    $null = Install-ReleaseTool psmux psmux/psmux "psmux-*-windows-$winArch.zip" psmux.exe @('tmux', 'pmux')
    $content = [IO.File]::ReadAllText((Join-Path $configRoot 'psmux/psmux.conf'))
    $content = $content.Replace('set -g default-shell pwsh', ('set -g default-shell "' + $pwshPath.Replace('\','/') + '"'))
    Write-ManagedFile (Join-Path $env:USERPROFILE '.psmux.conf') $content
}
function Get-Codium {
    $cmd = Get-Command codium.cmd -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($base in @((Join-Path $env:LOCALAPPDATA 'Programs/VSCodium'), (Join-Path $env:ProgramFiles 'VSCodium'))) {
        $candidate = Join-Path $base 'bin/codium.cmd'
        if (Test-Path -LiteralPath $candidate) { return $candidate }
    }
    if ($SkipPackages) { throw 'VSCodium is missing. Rerun without -SkipPackages.' }
    # Keep winget's native output out of the function pipeline: callers capture
    # Get-Codium's output as the executable path.
    & winget install --id VSCodium.VSCodium --exact --scope user --source winget --silent --accept-package-agreements --accept-source-agreements | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'VSCodium installation failed.' }
    $candidate = Join-Path $env:LOCALAPPDATA 'Programs/VSCodium/bin/codium.cmd'
    if (-not (Test-Path -LiteralPath $candidate)) { throw 'Cannot locate the installed codium.cmd.' }
    return $candidate
}
function Install-VSCodiumConfig {
    $codiumPath = Get-Codium
    $null = Install-ReleaseTool lazygit jesseduffield/lazygit "lazygit_*_windows_$(if ($arm) {'arm64'} else {'x86_64'}).zip" lazygit.exe
    $null = Install-ReleaseTool clangd clangd/clangd 'clangd-windows-*.zip' clangd.exe
    $null = Install-ReleaseTool shfmt mvdan/sh "shfmt_*_windows_$goArch.exe" shfmt.exe
    $source = Join-Path $configRoot 'vscodium'
    $destination = Join-Path $env:APPDATA 'VSCodium/User'
    $settings = Get-Content -LiteralPath (Join-Path $source 'settings.json') -Raw | ConvertFrom-Json -AsHashtable
    $settings['lazygit-vscode.lazygitPath'] = $script:toolState['lazygit']
    $settings['clangd.path'] = $script:toolState['clangd']
    $settings['shellformat.path'] = $script:toolState['shfmt']
    $settings['terminal.integrated.profiles.windows'] = [ordered]@{ 'PowerShell (dotfiles)' = [ordered]@{ path = $pwshPath; args = @('-NoLogo', '-ExecutionPolicy', 'Bypass') } }
    $settings['terminal.integrated.defaultProfile.windows'] = 'PowerShell (dotfiles)'
    $settings['terminal.integrated.env.windows'] = @{ PATH = "$toolBin;" + '${env:PATH}' }
    Write-ManagedFile (Join-Path $destination 'settings.json') ((ConvertTo-ConfigJson $settings) + "`n")
    Copy-ManagedFile (Join-Path $source 'keybindings.json') (Join-Path $destination 'keybindings.json')
    if (-not $SkipExtensions) {
        $installed = @(& $codiumPath --list-extensions)
        if ($LASTEXITCODE -ne 0) { throw 'Could not list VSCodium extensions.' }
        foreach ($extension in Get-Content -LiteralPath (Join-Path $source 'extensions.txt')) {
            if ($extension -and -not $extension.StartsWith('#') -and $installed -notcontains $extension) {
                & $codiumPath --install-extension $extension
                if ($LASTEXITCODE -ne 0) { throw "Failed to install $extension" }
            }
        }
        if ($installed -notcontains 'jongukc.dalbit') {
            & $codiumPath --install-extension (Join-Path $source 'dalbit.vsix')
            if ($LASTEXITCODE -ne 0) { throw 'Dalbit installation failed.' }
        }
    }
}
function Install-TerminalConfig {
    $palette = Get-Content -LiteralPath (Join-Path $configRoot 'windows-terminal/dalbit.json') -Raw | ConvertFrom-Json -AsHashtable
    $palette['profiles'] = @([ordered]@{
        guid = '{48df59ef-b110-5f22-a9f0-7f0c27adcb1c}'; name = 'Dotfiles PowerShell'
        commandline = '"' + $pwshPath + '" -NoLogo -ExecutionPolicy Bypass'
        startingDirectory = '%USERPROFILE%'; colorScheme = 'Dalbit'
    })
    $destination = Join-Path $env:LOCALAPPDATA 'Microsoft/Windows Terminal/Fragments/dotfiles/dalbit.json'
    Write-ManagedFile $destination ((ConvertTo-ConfigJson $palette) + "`n")
}

switch ($targets) {
    'all' { Install-PowerShellConfig; Install-PsmuxConfig; Install-VSCodiumConfig; Install-TerminalConfig }
    'tools' { Install-PowerShellConfig; Install-PsmuxConfig }
    'powershell' { Install-PowerShellConfig }
    'psmux' { Install-PsmuxConfig }
    'vscodium' { Install-VSCodiumConfig }
    'terminal' { Install-TerminalConfig }
}
Write-Host "[+] $targetList configured. Changed files backed up under $backupRoot (if any)."
Write-Host 'Open a new PowerShell session to load the prompt and updated PATH.'
