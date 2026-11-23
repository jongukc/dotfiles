# Managed by dotfiles/setup.ps1. Keep host-specific changes in $PROFILE.
$dotfilesTools = Join-Path $env:LOCALAPPDATA 'dotfiles'
$dotfilesBin = Join-Path $dotfilesTools 'bin'
if ((Test-Path -LiteralPath $dotfilesBin) -and ($env:PATH -split ';') -notcontains $dotfilesBin) {
    $env:PATH = "$dotfilesBin;$env:PATH"
}
$dotfilesState = Join-Path $dotfilesTools 'tools.json'
$dotfilesInstalled = $null
if (Test-Path -LiteralPath $dotfilesState) {
    $dotfilesInstalled = Get-Content -LiteralPath $dotfilesState -Raw | ConvertFrom-Json
    if ($dotfilesInstalled.pwsh) {
        $dotfilesPwshDir = Split-Path -Parent $dotfilesInstalled.pwsh
        if (($env:PATH -split ';') -notcontains $dotfilesPwshDir) { $env:PATH = "$dotfilesPwshDir;$env:PATH" }
    }
}

$env:STARSHIP_CONFIG = Join-Path $env:USERPROFILE '.config/starship.toml'
$env:VIRTUAL_ENV_DISABLE_PROMPT = '1'
if (Get-Command nvim -ErrorAction SilentlyContinue) {
    $env:EDITOR = 'nvim'
    Set-Alias vim nvim
} else { $env:EDITOR = 'codium --wait' }
if ($dotfilesInstalled -and $dotfilesInstalled.psmux) {
    $nativeTmux = Join-Path (Split-Path -Parent $dotfilesInstalled.psmux) 'tmux.exe'
    if (Test-Path -LiteralPath $nativeTmux) { Set-Alias tmux $nativeTmux }
}

# Equivalent to oh-my-zsh's commonly used git shortcuts.
foreach ($gitAlias in @('gc', 'gl', 'gp')) {
    if (Test-Path -LiteralPath "Alias:$gitAlias") { Remove-Item -LiteralPath "Alias:$gitAlias" -Force }
}
function g { git @args }
function gst { git status @args }
function ga { git add @args }
function gaa { git add --all @args }
function gc { git commit @args }
function gco { git checkout @args }
function gd { git diff @args }
function gl { git pull @args }
function gp { git push @args }
function .. { Set-Location .. }

function mdview {
    param([Parameter(Mandatory)][string]$Path, [Alias('b')][switch]$Browser)
    if (-not (Get-Command pandoc -ErrorAction SilentlyContinue)) { throw 'mdview requires pandoc.' }
    if (-not $Browser -and (Get-Command w3m -ErrorAction SilentlyContinue)) {
        pandoc $Path | w3m -T text/html
        return
    }
    $html = [IO.Path]::ChangeExtension((Resolve-Path -LiteralPath $Path).Path, '.html')
    $css = Join-Path $env:USERPROFILE '.local/share/mdview/style.css'
    $pandocArgs = @($Path, '--standalone', '--embed-resources', '-o', $html)
    if (Test-Path -LiteralPath $css) { $pandocArgs += @('--css', $css) }
    & pandoc @pandocArgs
    if ($LASTEXITCODE -eq 0) { Invoke-Item -LiteralPath $html }
}
function ph {
    paperhere open --tex paper/p.tex --pdf paper/p.pdf --build-cmd 'make -C paper' --browser firefox @args
}

# Only interactive sessions initialize line editing and prompt integrations.
if ([Environment]::UserInteractive -and -not [Console]::IsInputRedirected) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue
    if (Get-Command Set-PSReadLineOption -ErrorAction SilentlyContinue) {
        Set-PSReadLineOption -EditMode Vi -ViModeIndicator Cursor
        if ((Get-Command Set-PSReadLineOption).Parameters.ContainsKey('PredictionSource')) {
            Set-PSReadLineOption -PredictionSource History
        }
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        if (Get-Command fzf -ErrorAction SilentlyContinue) {
            Set-PSReadLineKeyHandler -Key Ctrl+r -ScriptBlock {
                $historyPath = (Get-PSReadLineOption).HistorySavePath
                if (Test-Path -LiteralPath $historyPath) {
                    $selected = Get-Content -LiteralPath $historyPath | Select-Object -Unique |
                        fzf --tac --no-sort --height=40% --layout=reverse --prompt='history> '
                    if ($selected) {
                        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                        [Microsoft.PowerShell.PSConsoleReadLine]::Insert([string]$selected)
                    }
                }
            }
        }
    }
    if (Get-Command starship -ErrorAction SilentlyContinue) {
        Invoke-Expression (& starship init powershell | Out-String)
    }
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Invoke-Expression (& zoxide init powershell | Out-String)
    }
}
$dotfilesEnv = Join-Path $env:USERPROFILE '.envvars.ps1'
if (Test-Path -LiteralPath $dotfilesEnv) { . $dotfilesEnv }
