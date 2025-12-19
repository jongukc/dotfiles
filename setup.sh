#!/usr/bin/bash

CONFIGS=$PWD/configs

function install {
    for pkg in $1; do
        if [ "$(pacsift --exact --name $pkg)" ]; then
            sudo pacman -Sy --needed --noconfirm $pkg
        elif [ "$(yay -Qk $pkg)" ]; then
            yay -Sy --needed --noconfirm $pkg
        fi
    done
}

function nosudo {
    echo "[*] nosudo"

    sudo bash -c "echo '$USER ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"
}

function git_setup {
    echo "[*] git_setup"

    install "git"

    cp $CONFIGS/git/gitconfig $HOME/.gitconfig
}

function gdb_setup {
    echo "[*] gdb_setup"

    install "gdb"

    cp $CONFIGS/gdb/gdbinit $HOME/.config/gdb/gdbinit
    cp $CONFIGS/gdb/gdbinit-gef.py $HOME/.gdbinit-gef.py
}

function i3_setup {
    echo "[*] i3_setup"

    cp $CONFIGS/i3/config $HOME/.config/i3/config
    cp $CONFIGS/i3/i3blocks.conf $HOME/.config/i3/i3blocks.conf
    mkdir -p $HOME/.screenlayout
    cp bg.png $HOME/.screenlayout/bg.png
    cp dual-monitor.sh $HOME/.screenlayout/dual-monitor.sh
}

function vim_setup {
    echo "[*] vim_setup"

    install "vim"

    cp $CONFIGS/vim/vimrc $HOME/.vimrc
}

function bash_setup {
    echo "[*] bash_setup"

    cp $CONFIGS/bash/bashrc $HOME/.bashrc
}

function zsh_setup {
    echo "[*] zsh_setup"

    install "zsh"

    echo "[+] oh-my-szh autojump autosuggestion"

    source $CONFIGS/zsh/ohmyzsh.sh --skip-chsh
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions

    rm $HOME/.zshrc
    cp $CONFIGS/zsh/zshrc $HOME/.zshrc
    cp $CONFIGS/zsh/p10k.zsh $HOME/.p10k.zsh

    install "fzf"

    echo "export FZF_CONFIGS_COMMAND='fd -type f'" >>$HOME/.envvars

    echo "[+] Changing default shell"
    sudo chsh -s $(which zsh) $USER
}

function tmux_setup {
    echo "[*] tmux_setup"

    install "tmux xclip"

    cp $CONFIGS/tmux/tmux.conf $HOME/.tmux.conf
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
}

function evince_setup {
    echo "[*] evince_setup"

    install "evince"
}

function fcitx5_setup {
    echo "[*] fcitx5_setup"

    install "fcitx5 fcitx5-configtool fcitx5-hangul fcitx5-gtk"

    cp -r $CONFIGS/fcitx5 $HOME/.config
}

function rclone_setup {
    echo "[*] rclone_setup"
    install "rclone inotify-tools"

    echo "[+] configure rclone, type absolute path to local directory you want to mount:"
    read -r LOCAL_DIR

    echo "[*] setup google-drive"
    rclone config

    mkdir $LOCAL_DIR
    rclone sync --verbose "google-drive:/" $LOCAL_DIR

    echo "[*] setup automatic syncing"
    SYNC_SCRIPT="$HOME/.config/rclone/rclone-sync.sh"
    cp $CONFIGS/rclone/rclone-sync.sh $SYNC_SCRIPT

    sudo loginctl enable-linger $USER
    if loginctl show-user $USER | grep "Linger=no"; then
        echo "[-] cannot enable Linger"
        exit 1
    fi

    mkdir -p $HOME/.config/systemd/user
    SERVICE_FILE=$HOME/.config/systemd/user/rclone_sync.google-drive.service
    if test -f $SERVICE_FILE; then
        echo "[-] Unit file already exists: $SERVICE_FILE - Not overwriting"
    else
        cat <<EOF >$SERVICE_FILE
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
    systemctl --user status rclone_sync.google-drive
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
    sudo usermod -aG docker $USER

    docker run hello-world

    docker build --build-arg user=$USER -t init-ubuntu:20.04 $CONFIGS/docker
}

function vscode_setup {
    install "visual-studio-code-bin"

    mkdir -p $HOME/.config/Code
    cp -r $CONFIGS/Code/User $HOME/.config/Code
}

function emacs_setup {
    install "emacs"

    git clone --depth 1 https://github.com/hlissner/doom-emacs $HOME/.emacs.d
    $HOME/.emacs.d/bin/doom install

    rm -rf $HOME/.doom.d
    cp -r $CONFIGS/emacs/doom.d $HOME/.doom.d
    $HOME/.emacs.d/bin/doom sync
}

function xclip_setup {
    echo "[*] xclip setup"
    install "xclip"

    echo "[*] setup listening on port 19988"
    echo "[-] please remove firewall for port 19988"
    XCLIP_SCRIPT="$HOME/.config/xclip/xclip-listen.sh"
    cp $CONFIGS/xclip/xclip-listen.sh $XCLIP_SCRIPT

    sudo loginctl enable-linger $USER
    if loginctl show-user $USER | grep "Linger=no"; then
        echo "[-] cannot enable Linger"
        exit 1
    fi

    mkdir -p $HOME/.config/systemd/user
    SERVICE_FILE=$HOME/.config/systemd/user/xclip_listener.service
    if test -f $SERVICE_FILE; then
        echo "[-] Unit file already exists: $SERVICE_FILE - Not overwritting"
    else
        cat <<EOF >$SERVICE_FILE
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
    systemctl --user status xclip_listener.service
}

lua_setup() {
    echo "[*] lua setup"

    sudo pacman -S lua5.1 liblua5.1-dev
    wget https://luarocks.org/releases/luarocks-3.12.2.tar.gz
    tar zxpf luarocks-3.12.2.tar.gz
    pushd luarocks-3.12.2 >>/dev/null
    ./configure && make && sudo make install
    popd >>/dev/null

    rm -rf luarocks-3.12.2*
}

nvim_setup() {
    echo "[*] nvim setup"

    # install rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source ~/.zshrc
    rustup update stable

    # install npm and dependencies
    install "npm"
    sudo npm install -g dockerfile-language-server-nodejs

    # install bob-nvim
    cargo install --git https://github.com/MordechaiHadad/bob.git

    # install neovim and config
    bob install stable
    bob use stable

    rm -rf $HOME/.config/nvim
    cp -r $CONFIGS/nvim $HOME/.config/nvim
}

###############################################################################

function setup {
    set -ex

    # nosudo
    git_setup
    gdb_setup
    i3_setup
    vim_setup
    bash_setup
    zsh_setup
    tmux_setup
    evince_setup
    fcitx5_setup
    rclone_setup
    pyenv_setup
    ranger_setup
    _docker_setup
    vscode_setup
    lua_setup
    nvim_setup
}

# Parse command line arguments
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
