# Dotfiles

Setup for macOS, Arch Linux, Ubuntu/Debian, and native Windows.

The `mac` branch keeps the portable development configs and skips Linux-only
desktop pieces such as Hyprland, Waybar, Rofi, Mako, Foot, SDDM, fcitx5, xclip,
and systemd user services.

## Supported Systems

- macOS on Apple Silicon and Intel
- Arch Linux (and derivatives: EndeavourOS, CachyOS, Garuda)
- Ubuntu / Debian
- Windows 10/11 (PowerShell 7, VSCodium, psmux; no WSL required)

## Usage

```bash
# Full setup on the current system
./setup.sh

# Install a specific component
./setup.sh -t brew
./setup.sh -t zsh
./setup.sh -t tmux
./setup.sh -t nvim
./setup.sh -t vscode
./setup.sh -t vscodium

# Install multiple components in the order listed
./setup.sh -t nvim,tmux,zsh
```

On Apple Silicon, `./setup.sh -t brew` installs and selects native Homebrew at
`/opt/homebrew`. A migrated Intel Homebrew at `/usr/local` is ignored.

On macOS, `./setup.sh` installs the portable development environment and skips
Linux-only desktop/session services.

### Windows

From a clone of this repository, run in PowerShell (Windows PowerShell 5.1 can
bootstrap PowerShell 7):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1

# Install/configure one component
.\setup.ps1 -Target powershell
.\setup.ps1 -Target psmux
.\setup.ps1 -Target vscodium
.\setup.ps1 -Target terminal

# Install/configure multiple components in the order listed
.\setup.ps1 -Target powershell,psmux,terminal

# Show the plan; or deploy using already-installed packages/extensions
.\setup.ps1 -DryRun
.\setup.ps1 -SkipPackages -SkipExtensions
```

Windows setup downloads portable PowerShell, Starship, zoxide, fzf, psmux,
LazyGit, clangd and shfmt from their official GitHub releases to
`%LOCALAPPDATA%\dotfiles`. It verifies GitHub's SHA-256 digest when provided.
Re-running uses installed tool versions; `-UpdateTools` checks for newer releases.
If VSCodium is missing, its user installer is installed with WinGet (App Installer
must be available). No administrator shell is needed for the portable tools.
Changed configs are backed up under `~/.dotfiles-backup/<timestamp>/`.

Open a new PowerShell session after setup. The managed profile is loaded from
`~/.config/powershell/dotfiles-profile.ps1` by the PowerShell and Windows PowerShell
AllHosts profiles; existing profile content is retained. The prompt adapts the
two-line Powerlevel10k layout: user/host, directory, Git branch/status, clock,
exit status, command duration, virtualenv, and Vi-mode prompt character. Host
accent colors follow `configs/zsh/p10k.zsh`. PSReadLine supplies Vi editing and
history suggestions; `Ctrl+r` opens fzf history, and zoxide supplies `z`/`zi`.
Git shortcuts (`gst`, `ga`, `gc`, `gco`, `gd`, `gl`, `gp`) and `vim`/`mdview`/`ph`
are migrated where their backing programs are installed. In particular, `gc`,
`gl`, and `gp` intentionally replace PowerShell's built-in aliases. Pandoc,
paperhere, and language runtimes are not installed by this setup.

Windows Terminal gains a **Dotfiles PowerShell** profile with the Dalbit palette.
Select it from its profile menu. Existing Terminal profiles/defaults are retained.
VSCodium's integrated terminal uses the managed PowerShell 7 profile automatically.

### VS Code and VSCodium

On Linux and macOS, `./setup.sh -t vscode` installs the migrated settings and
keybindings from `configs/Code/User/` and uses the extensions listed below.
The VS Code settings suppress the Workspace Trust dialog when opening a folder.
To deploy just the two configuration files, run
`python3 scripts/vscodium.py install --vscode --skip-extensions`.

`configs/vscodium/` contains this machine's settings, keymaps and extension list,
including the Neovim-style leader bindings, Code Telescope, Oil, Which Key,
4-space Prettier formatting, editor-area terminals and `Ctrl+b` sidebar toggle.
Only `settings.json` and `keybindings.json` are deployed; accounts, tokens,
extension storage and backups are excluded. Machine-specific binary/terminal
paths are omitted from the portable snapshot and set during deployment.

- Linux: `./setup.sh -t vscodium` (AUR on Arch, signed VSCodium repository on Debian).
- macOS: `./setup.sh -t vscodium` (Homebrew cask).
- Windows: `.\setup.ps1 -Target vscodium`.

Capture later changes, using Python 3 and the VSCodium CLI:

```bash
python3 scripts/vscodium.py snapshot --cli codium
```

On Windows, use `python` and pass `--cli` the full `codium.cmd` path if it is not
on PATH. Run the relevant setup target to restore the snapshot; changed files
are backed up first. Project `.prettierrc`/`.editorconfig` files still take
precedence over the user-level 4-space Prettier default.

Dalbit is installed from `configs/vscodium/dalbit.vsix` because it is not published
on Open VSX. It packages [jongukc/dalbit.vscode](https://github.com/jongukc/dalbit.vscode)
at revision `e5d2081bed3a18e84beb964f2273cbb036575afa`, with the upstream theme
and manifest unchanged. Rebuild it with `python3 scripts/build-dalbit.py`.

### psmux on Windows

`configs/psmux/psmux.conf` is deployed as `~/.psmux.conf`. `psmux`, `pmux` and
`tmux` invoke the native Windows implementation; the native `tmux.exe` preserves
tmux-shaped version output for integrations. The Unix config remains unchanged.

| Key | Action |
| --- | --- |
| `Ctrl+x` | Prefix (`Ctrl+x Ctrl+x` sends it to the application) |
| Prefix then `\` / `-` | Split left/right / top/bottom |
| `Alt+h/j/k/l` | Move between panes; forward to Vim when active |
| `Ctrl+h/l` | Previous / next window |
| `Alt+1` … `Alt+9` | Select window |
| Prefix then `r` | Reload `~/.psmux.conf` |
| Copy mode `v` / `y` | Select / copy to the Windows clipboard |

Mouse support, Vi copy mode, one-based windows, top status bar and Dalbit colors
are preserved. VSCodium passes `Alt+h/j/k/l` through to terminal applications;
Escape in an editor-area terminal reaches PowerShell's Vi mode and psmux copy
mode. Unix `ps`/`grep`, Wayland hooks, xclip and Bash-based TPM plugins
are replaced or omitted. Resurrect/Continuum reboot restoration is not migrated;
psmux's normal detach/reattach keeps running sessions alive. Existing sessions
are not terminated or reconfigured by setup.

### Validation

```bash
python3 -m unittest discover -s tests -v
bash -n setup.sh scripts/vscodium.sh
```

On Windows, `tests/Test-WindowsSetup.ps1` checks PowerShell syntax, the installed
prompt, and psmux configuration in an isolated temporary server namespace. It
requires the tools installed by `setup.ps1` and cleans up only its test session.

## Components

- **macOS**: Homebrew, git, GDB, bash, zsh, oh-my-zsh, tmux, Vim, Neovim, VS Code, pyenv, ranger, w3m, Lua, Docker Desktop, Chrome, iTerm2 (dalbit colorscheme), fonts, mdview assets
- **Linux WM**: Hyprland (waybar, rofi-wayland, mako, foot, hyprlock, hypridle)
- **Shell**: zsh (oh-my-zsh, powerlevel10k, fzf, autojump)
- **Editor**: Neovim, Vim, VS Code, VSCodium + Dalbit
- **Terminal**: foot (Linux), iTerm2 + dalbit colorscheme (macOS), tmux
- **Input**: fcitx5 (Hangul)
- **Dev**: git, gdb, pyenv, lua, docker, ranger
- **Other**: evince, rclone, Chrome, SDDM
