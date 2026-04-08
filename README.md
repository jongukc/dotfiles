# Dotfiles

Unified setup for Arch Linux and Ubuntu with Hyprland (Wayland).

## Supported Distros

- Arch Linux (and derivatives: EndeavourOS, CachyOS, Garuda)
- Ubuntu / Debian

## Usage

```bash
# Full setup
./setup.sh

# Install a specific component
./setup.sh -t hyprland
./setup.sh -t zsh
./setup.sh -t nvim
```

## Components

- **WM**: Hyprland (waybar, rofi-wayland, mako, foot, hyprlock, hypridle)
- **Shell**: zsh (oh-my-zsh, powerlevel10k, fzf, autojump)
- **Editor**: Neovim (via [bob](https://github.com/MordechaiHadad/bob)), Vim, VS Code
- **Terminal**: foot, tmux
- **Input**: fcitx5 (Hangul)
- **Dev**: git, gdb, pyenv, lua, docker, ranger
- **Other**: evince, rclone, Chrome, SDDM
