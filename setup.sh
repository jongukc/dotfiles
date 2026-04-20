#!/usr/bin/bash

set -e

CONFIGS="$PWD/configs"

# Distro detection
DISTRO=""
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
        arch|endeavouros|cachyos|garuda) DISTRO="arch" ;;
        ubuntu|debian|linuxmint|pop)     DISTRO="debian" ;;
        *)
            echo "Unsupported distro: $ID"
            exit 1
            ;;
    esac
else
    echo "Cannot detect distro: /etc/os-release not found"
    exit 1
fi

echo "[*] Detected distro family: $DISTRO"

# Package name mapping: arch name -> debian equivalent
function pkg {
    local name="$1"
    if [ "$DISTRO" = "debian" ]; then
        case "$name" in
            base-devel)              echo "build-essential" ;;
            lua51)                   echo "lua5.1 liblua5.1-dev" ;;
            docker)                  echo "docker.io" ;;
            visual-studio-code-bin)  echo "code" ;;
            google-chrome)           echo "google-chrome-stable" ;;
            ttf-jetbrains-mono-nerd) echo "fonts-jetbrains-mono" ;;
            noto-fonts-cjk)          echo "fonts-noto-cjk" ;;
            arc-gtk-theme)           echo "arc-theme" ;;
            xorg-xwayland)           echo "xwayland" ;;
            qt5-wayland)             echo "qtwayland5" ;;
            qt5-graphicaleffects)    echo "qml-module-qtgraphicaleffects" ;;
            qt5-quickcontrols2)      echo "qml-module-qtquick-controls2" ;;
            qt5-svg)                 echo "libqt5svg5" ;;
            hyprpolkitagent)         echo "polkitd" ;;
            fcitx5-gtk)              echo "fcitx5-frontend-gtk3 fcitx5-frontend-gtk4" ;;
            npm)                     echo "npm" ;;
            *)                       echo "$name" ;;
        esac
    else
        echo "$name"
    fi
}

# Distro-aware package installer
function install {
    case "$DISTRO" in
        arch)
            yay -Sy --needed --noconfirm "$@"
            ;;
        debian)
            sudo apt install -y "$@"
            ;;
    esac
}

function nosudo {
    echo "[*] nosudo"

    echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee "/etc/sudoers.d/$USER-nopasswd"
}

function yay_setup {
    echo "[*] yay_setup"

    if [ "$DISTRO" = "debian" ]; then
        echo "[+] Skipping yay on Debian-based distro"
        return
    fi

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

function apt_setup {
    echo "[*] apt_setup"

    if [ "$DISTRO" != "debian" ]; then
        echo "[+] Skipping apt_setup on Arch-based distro"
        return
    fi

    sudo apt update && sudo apt upgrade -y
    install $(pkg base-devel) curl wget git software-properties-common

    # VS Code repo
    if ! apt-cache policy code 2>/dev/null | grep -q "Candidate"; then
        echo "[+] Adding Microsoft VS Code repository"
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
        rm -f packages.microsoft.gpg
    fi

    # Google Chrome repo
    if ! apt-cache policy google-chrome-stable 2>/dev/null | grep -q "Candidate"; then
        echo "[+] Adding Google Chrome repository"
        wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor | sudo tee /etc/apt/keyrings/google-chrome.gpg >/dev/null
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list
    fi

    sudo apt update
}

function git_setup {
    echo "[*] git_setup"
    install git

    [ -f "$CONFIGS/git/gitconfig" ] && cp "$CONFIGS/git/gitconfig" "$HOME/.gitconfig"
}

function gdb_setup {
    echo "[*] gdb_setup"
    install gdb

    mkdir -p "$HOME/.config/gdb"
    [ -f "$CONFIGS/gdb/gdbinit" ] && cp "$CONFIGS/gdb/gdbinit" "$HOME/.config/gdb/gdbinit"
    [ -f "$CONFIGS/gdb/gdbinit-gef.py" ] && cp "$CONFIGS/gdb/gdbinit-gef.py" "$HOME/.gdbinit-gef.py"
}

function hyprland_setup {
    echo "[*] hyprland_setup"

    if [ "$DISTRO" = "debian" ]; then
        echo "[+] Installing Hyprland build dependencies on Debian..."
        install meson ninja-build cmake-extras cmake gettext gettext-base \
            fontconfig libfontconfig-dev libffi-dev libxml2-dev libdrm-dev \
            libxkbcommon-x11-dev libxkbregistry-dev libxkbcommon-dev libpixman-1-dev \
            libudev-dev libseat-dev seatd libxcb-dri3-dev libvulkan-dev \
            libegl-dev libgles2 libegl1-mesa-dev glslang-tools libinput-bin \
            libinput-dev libxcb-composite0-dev libavutil-dev libavcodec-dev \
            libavformat-dev libxcb-ewmh2 libxcb-ewmh-dev libxcb-present-dev \
            libxcb-icccm4-dev libxcb-render-util0-dev libxcb-res0-dev \
            libxcb-xinput-dev libpango1.0-dev libtomlplusplus-dev \
            $(pkg xorg-xwayland)

        echo ""
        echo "========================================================"
        echo "[!] Hyprland must be built from source on Ubuntu."
        echo "[!] See: https://wiki.hyprland.org/Getting-Started/Installation/"
        echo "========================================================"
        echo ""
        echo "[!] After installing Hyprland, re-run: ./setup.sh -t hyprland"
        echo "[!] to deploy configs."
    else
        install hyprland hyprpaper hyprlock hypridle
        install $(pkg xorg-xwayland)
        install xdg-desktop-portal-hyprland $(pkg hyprpolkitagent)
        install cpio cmake meson
    fi

    # Common packages (both distros)
    install waybar grim slurp wl-clipboard light mako
    install $(pkg qt5-wayland) $(pkg qt6-wayland)
    install rofi-wayland
    install foot

    # Deploy configs (identical for both distros)
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
}

function sddm_setup {
    echo "[*] sddm_setup"

    install sddm $(pkg qt5-graphicaleffects) $(pkg qt5-quickcontrols2) $(pkg qt5-svg)

    if [ "$DISTRO" = "arch" ]; then
        install sddm-silent-theme
    fi

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

function vim_setup {
    echo "[*] vim_setup"
    install vim
    [ -f "$CONFIGS/vim/vimrc" ] && cp "$CONFIGS/vim/vimrc" "$HOME/.vimrc"
}

function bash_setup {
    echo "[*] bash_setup"
    [ -f "$CONFIGS/bash/bashrc" ] && cp "$CONFIGS/bash/bashrc" "$HOME/.bashrc"
}

function zsh_setup {
    echo "[*] zsh_setup"
    install zsh fzf $(pkg autojump)

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
    install tmux xclip
    [ -f "$CONFIGS/tmux/tmux.conf" ] && cp "$CONFIGS/tmux/tmux.conf" "$HOME/.tmux.conf"

    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
    fi
}

function evince_setup {
    echo "[*] evince_setup"
    install evince
}

function zathura_setup {
    echo "[*] zathura_setup"
    install zathura zathura-pdf-mupdf

    mkdir -p "$HOME/.config/zathura"
    [ -f "$CONFIGS/zathura/zathurarc" ] && cp "$CONFIGS/zathura/zathurarc" "$HOME/.config/zathura/zathurarc"
}

function fcitx5_setup {
    echo "[*] fcitx5_setup"
    install fcitx5 fcitx5-configtool fcitx5-hangul $(pkg fcitx5-gtk)

    mkdir -p "$HOME/.config"
    [ -d "$CONFIGS/fcitx5" ] && cp -r "$CONFIGS/fcitx5" "$HOME/.config"
}

function rclone_setup {
    echo "[*] rclone_setup"
    install rclone inotify-tools

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

    if [ "$DISTRO" = "debian" ]; then
        if [ ! -d "$HOME/.pyenv" ]; then
            curl https://pyenv.run | bash
        fi
    else
        install pyenv
    fi
}

function ranger_setup {
    echo "[*] ranger_setup"
    install ranger
}

function w3m_setup {
    echo "[*] w3m_setup"
    install w3m

    rm -rf "$HOME/.w3m"
    [ -d "$CONFIGS/w3m" ] && cp -r "$CONFIGS/w3m" "$HOME/.w3m"
}

function _docker_setup {
    install $(pkg docker)

    sudo systemctl enable --now docker.service
    sudo usermod -aG docker "$USER"

    sleep 3

    sudo docker run hello-world
}

function vscode_setup {
    echo "[*] vscode_setup"

    install $(pkg visual-studio-code-bin)

    mkdir -p "$HOME/.config/Code"
    [ -d "$CONFIGS/Code/User" ] && cp -r "$CONFIGS/Code/User" "$HOME/.config/Code"
}

function xclip_setup {
    echo "[*] xclip setup"
    install xclip

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

    install $(pkg lua51) $(pkg base-devel) wget unzip

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

    install $(pkg npm)
    sudo npm install -g dockerfile-language-server-nodejs

    cargo install --git https://github.com/MordechaiHadad/bob.git

    "$HOME/.cargo/bin/bob" install stable
    "$HOME/.cargo/bin/bob" use stable

    rm -rf "$HOME/.config/nvim"
    [ -d "$CONFIGS/nvim" ] && cp -r "$CONFIGS/nvim" "$HOME/.config/nvim"
}

function chrome_setup {
    echo "[*] chrome_setup"

    install $(pkg google-chrome)
}

function font_setup {
    echo "[*] font_setup"

    install $(pkg ttf-jetbrains-mono-nerd)
    install $(pkg noto-fonts-cjk)

    if [ "$DISTRO" = "debian" ]; then
        echo "[+] Installing JetBrainsMono Nerd Font manually..."
        FONT_DIR="$HOME/.local/share/fonts"
        mkdir -p "$FONT_DIR"
        if [ ! -f "$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]; then
            wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz -O /tmp/JetBrainsMono.tar.xz
            tar xf /tmp/JetBrainsMono.tar.xz -C "$FONT_DIR"
            rm -f /tmp/JetBrainsMono.tar.xz
            fc-cache -fv
        fi
    fi
}

function mdview_setup {
    echo "[*] mdview_setup"

    [ -d "$CONFIGS/mdview" ] && sudo cp -r "$CONFIGS/mdview" /usr/share/
}

function theme_setup {
    echo "[*] theme_setup"

    install $(pkg arc-gtk-theme)

    if [ "$DISTRO" = "debian" ]; then
        install nwg-look
    else
        install nwg-look
    fi

    rm -rf "$HOME/.config/nwg-look"

    cp -r "$CONFIGS/nwg-look" "$HOME/.config/"
}
###############################################################################

function setup {
    set -e

    nosudo

    if [ "$DISTRO" = "arch" ]; then
        yay_setup
    else
        apt_setup
    fi

    git_setup
    gdb_setup
    hyprland_setup
    sddm_setup
    vim_setup
    bash_setup
    zsh_setup
    tmux_setup
    evince_setup
    zathura_setup
    fcitx5_setup
    ranger_setup
    w3m_setup
    xclip_setup
    pyenv_setup
    _docker_setup
    vscode_setup
    lua_setup
    nvim_setup
    chrome_setup
    font_setup
    theme_setup
    mdview_setup
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
