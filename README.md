# Dotfiles

Unified setup for macOS, Arch Linux, and Ubuntu/Debian.

The `mac` branch keeps the portable development configs and skips Linux-only
desktop pieces such as Hyprland, Waybar, Rofi, Mako, Foot, SDDM, fcitx5, xclip,
and systemd user services.

## Supported Systems

- macOS on Apple Silicon and Intel
- Arch Linux (and derivatives: EndeavourOS, CachyOS, Garuda)
- Ubuntu / Debian

## Usage

```bash
# Full setup on the current system
./setup.sh

# Install a specific component
./setup.sh -t brew
./setup.sh -t zsh
./setup.sh -t tmux
./setup.sh -t nvim
```

On Apple Silicon, `./setup.sh -t brew` installs and selects native Homebrew at
`/opt/homebrew`. A migrated Intel Homebrew at `/usr/local` is ignored.

On macOS, `./setup.sh` installs the portable development environment and skips
Linux-only desktop/session services.

## Components

- **macOS**: Homebrew, git, GDB, bash, zsh, oh-my-zsh, tmux, Vim, Neovim, VS Code, pyenv, ranger, w3m, Lua, Docker Desktop, Chrome, fonts, mdview assets
- **Linux WM**: Hyprland (waybar, rofi-wayland, mako, foot, hyprlock, hypridle)
- **Shell**: zsh (oh-my-zsh, powerlevel10k, fzf, autojump)
- **Editor**: Neovim, Vim, VS Code
- **Terminal**: foot, tmux
- **Input**: fcitx5 (Hangul)
- **Dev**: git, gdb, pyenv, lua, docker, ranger
- **Other**: evince, rclone, Chrome, SDDM
