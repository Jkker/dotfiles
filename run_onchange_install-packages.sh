#!/bin/bash
set -e

# --- Helpers ---
log_info() { echo -e "\033[0;34m[INFO]\033[0m $(date +'%Y-%m-%dT%H:%M:%S%z') $1"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $(date +'%Y-%m-%dT%H:%M:%S%z') $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $(date +'%Y-%m-%dT%H:%M:%S%z') $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $(date +'%Y-%m-%dT%H:%M:%S%z') $1"; }

has_command() { command -v "$1" >/dev/null 2>&1; }

# --- OS Detection ---
OS="$(uname -s)"
case "${OS}" in
    Linux*)     MACHINE=Linux;; 
    Darwin*)    MACHINE=Mac;; 
    *)          MACHINE="UNKNOWN";;
esac

log_info "Detected OS: $MACHINE"

# --- System Updates & Core Dependencies (Linux/Debian-based) ---
if [ "$MACHINE" == "Linux" ] && [ -f /etc/debian_version ]; then
    log_info "Running System Updates (Debian/Ubuntu)..."
    export DEBIAN_FRONTEND=noninteractive

    # Only run full system update if we have passwordless sudo or are root
    if sudo -n true 2>/dev/null || [ "$EUID" -eq 0 ]; then
        sudo apt-get update -qq
        sudo apt-get upgrade -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
        sudo apt-get autoremove -y -qq
        sudo apt-get clean

        # Security: Unattended Upgrades
        log_info "Configuring Unattended Upgrades..."
        sudo apt-get install -y -qq unattended-upgrades apt-listchanges
        cat <<EOF | sudo tee /etc/apt/apt.conf.d/51unattended-upgrades-local > /dev/null
Unattended-Upgrade::Allowed-Origins {
    "\${distro_id}:\${distro_codename}";
    "\${distro_id}:\${distro_codename}-security";
    "\${distro_id}ESMApps:\${distro_codename}-apps-security";
    "\${distro_id}ESM:\${distro_codename}-infra-security";
};
Unattended-Upgrade::Package-Blacklist {};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
EOF
        sudo systemctl enable --now unattended-upgrades
    else
        log_warn "Sudo not available or password required. Skipping system updates and unattended-upgrades."
    fi
fi

# --- Install Dependencies ---
install_dependencies() {
    local pkgs=("zsh" "curl" "git" "ca-certificates" "gnupg" "build-essential")
    local missing_pkgs=()

    for pkg in "${pkgs[@]}"; do
        if ! has_command "$pkg" && ! dpkg -s "$pkg" >/dev/null 2>&1; then
             missing_pkgs+=("$pkg")
        fi
done

    if [ ${#missing_pkgs[@]} -eq 0 ]; then
        log_info "Core dependencies met."
    else
        log_info "Installing missing dependencies: ${missing_pkgs[*]}..."
        if [ "$MACHINE" == "Linux" ]; then
             if has_command apt-get; then
                sudo apt-get update && sudo apt-get install -y "${missing_pkgs[@]}"
             elif has_command dnf; then
                sudo dnf install -y "${missing_pkgs[@]}"
             elif has_command pacman; then
                sudo pacman -S --noconfirm "${missing_pkgs[@]}"
             elif has_command apk; then
                sudo apk add "${missing_pkgs[@]}"
             fi
        elif [ "$MACHINE" == "Mac" ]; then
             if has_command brew; then
                brew install "${missing_pkgs[@]}"
             else
                log_warn "Homebrew not found. Please install: ${missing_pkgs[*]}"
             fi
        fi
    fi
}
install_dependencies

# --- Mise Installation & Setup ---
if ! has_command mise; then
    log_info "Installing mise..."
    curl https://mise.run | sh
    export PATH="$HOME/.local/bin:$PATH"
fi

MISE_BIN="$(command -v mise)"
if [ -z "$MISE_BIN" ]; then
    # Fallbacks
    for loc in "$HOME/.local/bin/mise" "/opt/homebrew/bin/mise" "/usr/local/bin/mise" "/usr/bin/mise"; do
        if [ -x "$loc" ]; then MISE_BIN="$loc"; break; fi
    done
fi

if [ -x "$MISE_BIN" ]; then
    log_success "Mise found at: $MISE_BIN"
    
    # Trust config
    MISE_CONFIG="$HOME/.config/mise/config.toml"
    if [ -f "$MISE_CONFIG" ]; then
        "$MISE_BIN" trust "$MISE_CONFIG" || true
        "$MISE_BIN" trust "$HOME" || true
    fi

    # Install tools
    log_info "Installing tools via mise..."
    "$MISE_BIN" install
    "$MISE_BIN" upgrade

    # System-wide access (Linux + Sudo)
    if [ "$MACHINE" == "Linux" ] && sudo -n true 2>/dev/null; then
        log_info "Configuring system-wide access for mise..."
        [ ! -f "/usr/local/bin/mise" ] && sudo ln -sf "$MISE_BIN" /usr/local/bin/mise
        
        if [ -f "$MISE_CONFIG" ]; then
            sudo mkdir -p /etc/mise
            # Only link if not already linked
            if [ "$(readlink -f /etc/mise/config.toml 2>/dev/null)" != "$(readlink -f "$MISE_CONFIG")" ]; then
                sudo ln -sf "$MISE_CONFIG" /etc/mise/config.toml
            fi
            sudo "$MISE_BIN" trust "/etc/mise/config.toml"
        fi

        # Shim linking
        SHIMS_DIR="$HOME/.local/share/mise/shims"
        if [ -d "$SHIMS_DIR" ]; then
             log_info "Symlinking shims to /usr/local/bin..."
             for shim in "$SHIMS_DIR"/*; do
                 [ -e "$shim" ] || continue
                 sudo ln -sf "$shim" "/usr/local/bin/$(basename "$shim")"
             done
        fi
    fi
fi

# --- Shell Setup ---
CURRENT_SHELL_PATH=$(getent passwd "$USER" | cut -d: -f7 2>/dev/null || echo $SHELL)
TARGET_SHELL_PATH=$(command -v zsh)

if [ -n "$TARGET_SHELL_PATH" ] && [ "$CURRENT_SHELL_PATH" != "$TARGET_SHELL_PATH" ]; then
    log_info "Changing default shell to zsh..."
    if sudo -n true 2>/dev/null; then
         sudo chsh -s "$TARGET_SHELL_PATH" "$USER" || log_warn "Failed to change shell. Try: chsh -s $TARGET_SHELL_PATH"
    else
         # Try without sudo
         chsh -s "$TARGET_SHELL_PATH" || log_warn "Failed to change shell. Try manually: chsh -s $TARGET_SHELL_PATH"
    fi
fi

log_success "Setup Complete! Please restart your terminal or log out and back in."
