#!/bin/bash
set -e

# Logging helper
log() { echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')] $1"; }

log "Starting System Setup..."

# --- 1. System Updates ---
# Ensure non-interactive upgrades
export DEBIAN_FRONTEND=noninteractive

log "Updating and upgrading packages..."
sudo apt-get update -qq
# Upgrade packages, keeping existing config files if conflicts arise
sudo apt-get upgrade -y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
sudo apt-get autoremove -y -qq
sudo apt-get clean

# --- 2. Security: Unattended Upgrades ---
log "Configuring Unattended Upgrades..."
sudo apt-get install -y -qq unattended-upgrades apt-listchanges

# Write configuration (overwrites if exists)
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

# --- 3. Docker Installation ---
log "Installing Docker prerequisites..."
sudo apt-get install -y -qq ca-certificates curl gnupg

# Add GPG key only if missing
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

# Add Docker repository
log "Configuring Docker repository..."
echo \
  "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

log "Installing Docker Engine..."
sudo apt-get update -qq
sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# --- 4. User Permissions ---
log "Configuring user permissions..."
sudo groupadd -f docker
sudo usermod -aG docker "$USER"

log "Setup Complete. Please log out and back in."
