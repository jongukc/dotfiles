# Sourced by setup.sh after ROOT and CONFIGS are defined.
function vscodium_setup {
    echo "[*] vscodium_setup"
    if [ "$(uname -s)" = "Darwin" ]; then
        brew_install_cask vscodium
        brew_install python lazygit shfmt
        if ! command -v clangd >/dev/null 2>&1; then
            brew_install llvm
            export PATH="$(brew --prefix llvm)/bin:$PATH"
        fi
        local codium_cli="$(command -v codium || true)"
        [ -n "$codium_cli" ] || codium_cli="/Applications/VSCodium.app/Contents/Resources/app/bin/codium"
    else
        if [ "$DISTRO" = "arch" ]; then
            command -v yay >/dev/null 2>&1 || yay_setup
            install vscodium-bin python clang shfmt lazygit
        else
            install python3 curl gnupg clangd shfmt
            if ! command -v codium >/dev/null 2>&1; then
                sudo mkdir -p /usr/share/keyrings
                curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg |
                    gpg --dearmor | sudo tee /usr/share/keyrings/vscodium-archive-keyring.gpg >/dev/null
                printf '%s\n' 'deb [arch=amd64,arm64 signed-by=/usr/share/keyrings/vscodium-archive-keyring.gpg] https://download.vscodium.com/debs vscodium main' |
                    sudo tee /etc/apt/sources.list.d/vscodium.list >/dev/null
                sudo apt update
                install codium
            fi
        fi
        local codium_cli="$(command -v codium)"
    fi
    export PATH="$HOME/.local/bin:$PATH"
    python3 "$ROOT/scripts/vscodium.py" install --cli "$codium_cli"
}
