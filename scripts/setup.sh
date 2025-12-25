#!/usr/bin/env zsh

# Install mise if not available
if ! command -v mise >/dev/null 2>&1; then
  echo "Installing mise..."
  curl https://mise.run | sh
fi

# set ZDOTDIR in .zshenv if not already set
if ! grep -q 'export ZDOTDIR=~/env' "$HOME/.zshenv"; then
  echo 'export ZDOTDIR=~/env
[[ -f $ZDOTDIR/.zshenv ]] && . $ZDOTDIR/.zshenv' >> "$HOME/.zshenv"
fi

# Ensure ZDOTDIR is set for this script
export ZDOTDIR="${ZDOTDIR:-$HOME/env}"
export MISE_GLOBAL_CONFIG_FILE="$ZDOTDIR/.config/mise/config.toml"

# Ensure ~/.local/bin is in PATH (where mise installs)
export PATH="$HOME/.local/bin:$PATH"

MISE_BIN="$(command -v mise)"
if [ -z "$MISE_BIN" ] || [ ! -x "$MISE_BIN" ]; then
  if [ -x "$HOME/.local/bin/mise" ]; then
    MISE_BIN="$HOME/.local/bin/mise"
  elif [ -x "/opt/homebrew/bin/mise" ]; then
    MISE_BIN="/opt/homebrew/bin/mise"
  elif [ -x "/usr/local/bin/mise" ]; then
    MISE_BIN="/usr/local/bin/mise"
  elif [ -x "/usr/bin/mise" ]; then
    MISE_BIN="/usr/bin/mise"
  fi
fi

echo "Trusting mise config for current user..."
if [ -f "$MISE_GLOBAL_CONFIG_FILE" ]; then
  mise trust "$MISE_GLOBAL_CONFIG_FILE"
  mise trust "$ZDOTDIR"
else
  echo "Warning: Mise config not found at $MISE_GLOBAL_CONFIG_FILE"
fi

# Activate mise to run upgrade
eval "$(mise activate zsh)"
mise upgrade

# --- System-wide Access Setup ---

echo "Configuring system-wide access for mise..."

if [ ! -x "$MISE_BIN" ]; then
    echo "Error: mise binary not found at $MISE_BIN"
    exit 1
fi

# 1. Symlink mise binary to /usr/local/bin
if [ "$MISE_BIN" != "/usr/local/bin/mise" ]; then
    sudo ln -sf "$MISE_BIN" /usr/local/bin/mise
fi

# 2. Expose global config to root via /etc/mise
#    This allows root to share the tools configuration.
if [ -f "$MISE_GLOBAL_CONFIG_FILE" ]; then
    sudo mkdir -p /etc/mise
    sudo ln -sf "$MISE_GLOBAL_CONFIG_FILE" /etc/mise/config.toml
    
    # Trust the config file for ROOT user
    echo "Trusting mise config for root..."
    # Trust the system path
    sudo mise trust "/etc/mise/config.toml"
    # Trust the original path (symlink target)
    sudo mise trust "$MISE_GLOBAL_CONFIG_FILE"
    # Trust the project dir for root as well
    sudo mise trust "$ZDOTDIR"
fi

# 3. Symlink all shims to /usr/local/bin
SHIMS_DIR="$HOME/.local/share/mise/shims"
if [ ! -d "$SHIMS_DIR" ] && [ -d "$HOME/Library/Application Support/mise/shims" ]; then
    SHIMS_DIR="$HOME/Library/Application Support/mise/shims"
fi

if [ -d "$SHIMS_DIR" ]; then
    echo "Symlinking shims to /usr/local/bin..."
    for shim in "$SHIMS_DIR"/*; do
        [ -e "$shim" ] || continue
        shim_name="$(basename "$shim")"
        sudo ln -sf "$shim" "/usr/local/bin/$shim_name"
    done
fi

echo "Setup complete."
