# Integration checks use only a private psmux namespace/session, never user sessions.
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
foreach ($path in @((Join-Path $repoRoot 'setup.ps1'), (Join-Path $repoRoot 'configs/powershell/profile.ps1'))) {
    $tokens = $null; $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors) { throw ($parseErrors | Out-String) }
}
$tools = Get-Content -LiteralPath (Join-Path $env:LOCALAPPDATA 'dotfiles/tools.json') -Raw | ConvertFrom-Json
$env:TERM = 'xterm-256color'
$env:STARSHIP_CONFIG = Join-Path $env:USERPROFILE '.config/starship.toml'
$env:STARSHIP_SHELL = 'powershell'
$promptErrors = Join-Path ([IO.Path]::GetTempPath()) ('dotfiles-prompt-' + [guid]::NewGuid().ToString('N') + '.log')
try {
    $null = & $tools.starship prompt --status 0 2> $promptErrors
    if ($LASTEXITCODE -ne 0 -or (Get-Item -LiteralPath $promptErrors).Length -gt 0) {
        throw "Starship config diagnostics: $(Get-Content -LiteralPath $promptErrors -Raw)"
    }
} finally { if (Test-Path -LiteralPath $promptErrors) { Remove-Item -LiteralPath $promptErrors } }

$testSession = 'dotfiles-test-' + [guid]::NewGuid().ToString('N').Substring(0, 10)
function Invoke-TestPsmux {
    $output = & $tools.psmux -L $testSession @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "psmux failed: $output" }
    return ($output | Out-String).Trim()
}
try {
    $created = Invoke-TestPsmux -f (Join-Path $env:USERPROFILE '.psmux.conf') new-session -d -s $testSession
    if ($created -match '(?i)warning|error') { throw "Config diagnostics: $created" }
    foreach ($item in @(@('prefix','C-x'), @('base-index','1'), @('status-position','top'))) {
        $actual = Invoke-TestPsmux show-options -g -t $testSession $item[0]
        if ($actual -ne "$($item[0]) $($item[1])") { throw "Unexpected option: $actual" }
    }
    $bindings = Invoke-TestPsmux list-keys -T prefix
    if (-not $bindings.Contains('split-window -h') -or -not $bindings.Contains('split-window -v')) {
        throw 'Missing split bindings.'
    }
    $null = Invoke-TestPsmux split-window -h -t $testSession
    $panes = Invoke-TestPsmux list-panes -t $testSession -F '#{pane_id}'
    if (($panes -split "`n").Count -ne 2) { throw "Expected two panes, got: $panes" }
    $tmuxBinary = Join-Path (Split-Path -Parent $tools.psmux) 'tmux.exe'
    $version = @(& $tmuxBinary -V)
    if ($version[0] -notmatch '^tmux\s') { throw "Incompatible tmux version response: $version" }
} finally {
    & $tools.psmux -L $testSession kill-session -t $testSession | Out-Null
}
Write-Output 'PASS: PowerShell syntax, Starship configuration, psmux config/options/splits, native tmux alias.'
