#!/usr/bin/bash

set -e

CONFIGS="$PWD/configs"

function install {
    for pkg in $1; do
        yay -Sy --needed --noconfirm $pkg
    done
}

function nosudo {
    echo "[*] nosudo"

    echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$USER-nopasswd"
}

function yay_setup {
    echo "[*] yay_setup"

    sudo pacman -Sy --needed --noconfirm git base-devel

    if ! command -v yay &>/dev/null; then
        echo "[-] yay not found, building from AUR..."
        rm -rf /tmp/yay
        git clone https://aur.archlinux.org/yay.git /tmp/yay
        pushd /tmp/yay
        makepkg -si --noconfirm
        popd
        rm -rf /tmp/yay
    else
        echo "[+] yay is already installed"
    fi
}

function git_setup {
    echo "[*] git_setup"
    install "git"

    [ -f "$CONFIGS/git/gitconfig" ] && cp "$CONFIGS/git/gitconfig" "$HOME/.gitconfig"
}

function gdb_setup {
    echo "[*] gdb_setup"
    install "gdb"

    mkdir -p "$HOME/.config/gdb"
    [ -f "$CONFIGS/gdb/gdbinit" ] && cp "$CONFIGS/gdb/gdbinit" "$HOME/.config/gdb/gdbinit"
    [ -f "$CONFIGS/gdb/gdbinit-gef.py" ] && cp "$CONFIGS/gdb/gdbinit-gef.py" "$HOME/.gdbinit-gef.py"
}

# function i3_setup {
#     echo "[*] i3_setup"
#
#     install "xorg xorg-xinit i3-wm i3status i3lock dmenu xterm"
#     install "rofi"
#     install "feh"
#     install "polybar"
#
#     mkdir -p "$HOME/.config/i3"
#     [ -f "$CONFIGS/i3/config" ] && cp "$CONFIGS/i3/config" "$HOME/.config/i3/config"
#     [ -d "$CONFIGS/i3/scripts" ] && cp -r "$CONFIGS/i3/scripts" "$HOME/.config/i3"
#
#     mkdir -p "$HOME/.config/rofi"
#     cp -r "$CONFIGS/rofi" "$HOME/.config"
#     cp -r "$CONFIGS/rofi_themes/themes" "$HOME/.local/share/rofi"
#
#     mkdir -p "$HOME/.config/polybar"
#     cp -r "$CONFIGS/polybar" "$HOME/.config"
#
#     mkdir -p "$HOME/.screen"
#     cp screen.sh "$HOME/.screen"
#     cp bg.png "$HOME/.screen"
# }

function hyprland_setup {
    echo "[*] hyprland_setup"

    install "hyprland hyprpaper hyprlock hypridle"
    install "waybar grim slurp wl-clipboard light mako xorg-xwayland"
    install "xdg-desktop-portal-hyprland hyprpolkitagent"
    install "qt5-wayland qt6-wayland"
    install "rofi-wayland"
    install "foot"
    install "cpio cmake meson"

    rm -rf "$HOME/.config/hypr"
    rm -rf "$HOME/.config/rofi"
    rm -rf "$HOME/.config/waybar"
    rm -rf "$HOME/.config/foot"
    rm -rf "$HOME/.config/mako"

    cp -r "$CONFIGS/hypr" "$HOME/.config/"
    cp -r "$CONFIGS/rofi" "$HOME/.config/"
    cp -r "$CONFIGS/waybar" "$HOME/.config/"
    cp -r "$CONFIGS/foot" "$HOME/.config/"
    cp -r "$CONFIGS/mako" "$HOME/.config/"

    mkdir -p "$HOME/.screen"
    [ -f "bg.png" ] && cp bg.png "$HOME/.screen"

    # hyprpm update
    # yes | hyprpm add https://github.com/outfoxxed/hy3
    # hyprpm reload -n
    # hyprpm enable hy3
}

function sddm_setup {
    echo "[*] sddm_setup"

    install "sddm qt5-graphicaleffects qt5-quickcontrols2 qt5-svg"
    install "sddm-silent-theme"

    sudo touch /etc/sddm.conf
    cat <<EOF | sudo tee /etc/sddm.conf >/dev/null
[General]
InputMethod=qtvirtualkeyboard
GreeterEnvironment=QML2_IMPORT_PATH=/usr/share/sddm/themes/silent/components/,QT_IM_MODULE=qtvirtualkeyboard

[Theme]
Current=silent

EOF
    sudo systemctl enable sddm
}

function sway_setup {
    echo "[*] sway_setup"

    install "sway swaylock swayidle waybar grim slurp wl-clipboard light mako polkit-gnome xorg-xwayland"
    install "rofi-wayland"

    mkdir -p "$HOME/.config/sway"
    [ -f "$CONFIGS/sway/config" ] && cp "$CONFIGS/sway/config" "$HOME/.config/sway/config"
    [ -d "$CONFIGS/sway/scripts" ] && cp -r "$CONFIGS/sway/scripts" "$HOME/.config/sway"
    chmod +x "$HOME/.config/sway/scripts/"*

    mkdir -p "$HOME/.config/rofi"
    cp -r "$CONFIGS/rofi" "$HOME/.config"

    mkdir -p "$HOME/.config/waybar"
    [ -f "$CONFIGS/waybar/config" ] && cp "$CONFIGS/waybar/config" "$HOME/.config/waybar/config"
    [ -f "$CONFIGS/waybar/style.css" ] && cp "$CONFIGS/waybar/style.css" "$HOME/.config/waybar/style.css"

    mkdir -p "$HOME/.screen"
    cp bg.png "$HOME/.screen"
}

function vim_setup {
    echo "[*] vim_setup"
    install "vim"
    [ -f "$CONFIGS/vim/vimrc" ] && cp "$CONFIGS/vim/vimrc" "$HOME/.vimrc"
}

function bash_setup {
    echo "[*] bash_setup"
    [ -f "$CONFIGS/bash/bashrc" ] && cp "$CONFIGS/bash/bashrc" "$HOME/.bashrc"
}

function zsh_setup {
    echo "[*] zsh_setup"
    install "zsh fzf autojump"

    echo "[+] oh-my-zsh setup"

    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        if [ -f "$CONFIGS/zsh/ohmyzsh.sh" ]; then
            sh "$CONFIGS/zsh/ohmyzsh.sh" --unattended
        else
            sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        fi
    fi

    echo "[+] installing plugins/themes"
    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    fi

    if [ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    fi

    rm -f "$HOME/.zshrc"
    [ -f "$CONFIGS/zsh/zshrc" ] && cp "$CONFIGS/zsh/zshrc" "$HOME/.zshrc"
    [ -f "$CONFIGS/zsh/p10k.zsh" ] && cp "$CONFIGS/zsh/p10k.zsh" "$HOME/.p10k.zsh"

    touch "$HOME/.envvars"
    if ! grep -q "FZF_CONFIGS_COMMAND" "$HOME/.envvars"; then
        echo "export FZF_CONFIGS_COMMAND='fd -type f'" >>"$HOME/.envvars"
    fi

    echo "[+] Changing default shell to zsh"
    sudo chsh -s "$(which zsh)" "$USER"
}

function tmux_setup {
    echo "[*] tmux_setup"
    install "tmux xclip"
    [ -f "$CONFIGS/tmux/tmux.conf" ] && cp "$CONFIGS/tmux/tmux.conf" "$HOME/.tmux.conf"

    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    fi
}

function evince_setup {
    echo "[*] evince_setup"
    install "evince"
}

function fcitx5_setup {
    echo "[*] fcitx5_setup"
    install "fcitx5 fcitx5-configtool fcitx5-hangul fcitx5-gtk"

    mkdir -p "$HOME/.config"
    [ -d "$CONFIGS/fcitx5" ] && cp -r "$CONFIGS/fcitx5" "$HOME/.config"
}

function rclone_setup {
    echo "[*] rclone_setup"
    install "rclone inotify-tools"

    echo "[+] configure rclone, type absolute path to local directory you want to mount:"
    read -r LOCAL_DIR

    echo "[*] setup google-drive"
    rclone config

    mkdir -p "$LOCAL_DIR"
    rclone sync --verbose "google-drive:/" "$LOCAL_DIR"

    echo "[*] setup automatic syncing"
    mkdir -p "$HOME/.config/rclone"
    SYNC_SCRIPT="$HOME/.config/rclone/rclone-sync.sh"
    [ -f "$CONFIGS/rclone/rclone-sync.sh" ] && cp "$CONFIGS/rclone/rclone-sync.sh" "$SYNC_SCRIPT"
    chmod +x "$SYNC_SCRIPT"

    sudo loginctl enable-linger "$USER"

    mkdir -p "$HOME/.config/systemd/user"
    SERVICE_FILE="$HOME/.config/systemd/user/rclone_sync.google-drive.service"

    if [ -f "$SERVICE_FILE" ]; then
        echo "[-] Unit file already exists: $SERVICE_FILE - Not overwriting"
    else
        cat <<EOF >"$SERVICE_FILE"
[Unit]
Description=rclone-sync google-drive

[Service]
ExecStart=$SYNC_SCRIPT google-drive: $LOCAL_DIR

[Install]
WantedBy=default.target
EOF
    fi
    systemctl --user daemon-reload
    systemctl --user enable --now rclone_sync.google-drive
}

function pyenv_setup {
    echo "[*] pyenv_setup"
    install "pyenv"
}

function ranger_setup {
    echo "[*] ranger_setup"
    install "ranger"
}

function _docker_setup {
    install "docker"

    sudo systemctl enable --now docker.service
    sudo usermod -aG docker "$USER"

    # Wait for docker socket to be ready
    sleep 3

    sudo docker run hello-world
}

function vscode_setup {
    echo "[*] vscode_setup"

    install "visual-studio-code-bin"

    mkdir -p "$HOME/.config/Code"
    [ -d "$CONFIGS/Code/User" ] && cp -r "$CONFIGS/Code/User" "$HOME/.config/Code"
}

function emacs_setup {
    echo "[*] emacs_setup"
    install "emacs"

    if [ ! -d "$HOME/.emacs.d" ]; then
        git clone --depth 1 https://github.com/hlissner/doom-emacs "$HOME/.emacs.d"
        "$HOME/.emacs.d/bin/doom" install
    fi

    rm -rf "$HOME/.doom.d"
    [ -d "$CONFIGS/emacs/doom.d" ] && cp -r "$CONFIGS/emacs/doom.d" "$HOME/.doom.d"
    "$HOME/.emacs.d/bin/doom" sync
}

function xclip_setup {
    echo "[*] xclip setup"
    install "xclip"

    echo "[*] setup listening on port 19988"

    mkdir -p "$HOME/.config/xclip"
    XCLIP_SCRIPT="$HOME/.config/xclip/xclip-listener.sh"
    [ -f "$CONFIGS/xclip/xclip-listener.sh" ] && cp "$CONFIGS/xclip/xclip-listener.sh" "$XCLIP_SCRIPT"
    chmod +x "$XCLIP_SCRIPT"

    sudo loginctl enable-linger "$USER"

    mkdir -p "$HOME/.config/systemd/user"
    SERVICE_FILE="$HOME/.config/systemd/user/xclip_listener.service"

    if [ -f "$SERVICE_FILE" ]; then
        echo "[-] Unit file already exists: $SERVICE_FILE - Not overwriting"
    else
        cat <<EOF >"$SERVICE_FILE"
[Unit]
Description=Network copy backend for tmux based on xclip
After=syslog.target network.target sockets.target network-online.target multi-user.target

[Service]
ExecStart=$XCLIP_SCRIPT

[Install]
WantedBy=default.target
EOF
    fi

    systemctl --user daemon-reload
    systemctl --user enable --now xclip_listener.service
}

function lua_setup() {
    echo "[*] lua setup"

    install "lua51 base-devel wget unzip"

    wget https://luarocks.org/releases/luarocks-3.12.2.tar.gz
    tar zxpf luarocks-3.12.2.tar.gz
    pushd luarocks-3.12.2 >/dev/null
    ./configure --lua-version=5.1 && make && sudo make install
    popd >/dev/null

    rm -rf luarocks-3.12.2*
}

function nvim_setup() {
    echo "[*] nvim setup"

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    . "$HOME/.cargo/env"
    rustup update stable

    install "npm"
    sudo npm install -g dockerfile-language-server-nodejs

    cargo install --git https://github.com/MordechaiHadad/bob.git

    "$HOME/.cargo/bin/bob" install stable
    "$HOME/.cargo/bin/bob" use stable

    rm -rf "$HOME/.config/nvim"
    [ -d "$CONFIGS/nvim" ] && cp -r "$CONFIGS/nvim" "$HOME/.config/nvim"
}

function chrome_setup {
    echo "[*] chrome_setup"

    install "google-chrome"
}

function font_setup {
    echo "[*] font_setup"

    install "ttf-jetbrains-mono-nerd"
    install "noto-fonts-cjk"
}

function theme_setup {
    echo "[*] theme_setup"

    install "arc-gtk-theme"

    rm -rf "$HOME/.config/nwg-look"

    cp -r "$CONFIGS/nwg-look" "$HOME/.config/"
}
###############################################################################

function setup {
    set -e

    nosudo
    yay_setup
    git_setup
    gdb_setup
    # i3_setup
    # sway_setup
    hyprland_setup
    sddm_setup
    vim_setup
    bash_setup
    zsh_setup
    tmux_setup
    evince_setup
    fcitx5_setup
    ranger_setup
    xclip_setup
    pyenv_setup
    _docker_setup
    vscode_setup
    lua_setup
    nvim_setup
    chrome_setup
    font_setup
    theme_setup
    # rclone_setup
}

TARGET="all"
while getopts "t:" opt; do
    case $opt in
    t)
        TARGET=$OPTARG
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
done

if [ "$TARGET" == "all" ]; then
    setup
else
    if declare -f "${TARGET}_setup" >/dev/null; then
        "${TARGET}_setup"
    elif declare -f "${TARGET}" >/dev/null; then
        "${TARGET}"
    else
        echo "Error: Function ${TARGET}_setup or ${TARGET} not found"
        exit 1
    fi
fi
