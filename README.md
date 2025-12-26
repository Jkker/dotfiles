# Dotfiles

Personal dotfiles configuration, managed with chezmoi.

## Overview

This repository contains configuration for my development environment, including shell (zsh), terminal utilities, and other tools. While the repository is public, it includes encrypted sensitive files (SSH keys, API tokens) that require a passphrase to decrypt.

The core shell and terminal setup is public and can be used by others.

## Installation

### Full Setup (Requires Passphrase)

To install everything, including encrypted secrets:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin init --apply Jkker
```

This will prompt for the encryption passphrase.

### Public Configuration Only

To install only the public configurations (shell, terminal, tools) and skip encrypted files:

```sh
sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin init init --apply Jkker --exclude=encrypted
```

## Usage

### Pull the latest changes and apply

```sh
chezmoi update
```

## Automated System Setup

The `run_onchange_install-packages.sh.tmpl` script automatically runs during `chezmoi apply` to bootstrap the system based on the OS.

### Linux (Ubuntu/Debian)
*   **System Updates**: Updates and upgrades `apt` packages.
*   **Environment Detection**: Detects WSL or Server environments to apply specific configurations (e.g., passwordless sudo for WSL, Docker for servers).
*   **Package Installation**: Installs essential tools like `git`, `curl`, `zsh`, `build-essential`, and others.
*   **Security**: Configures `unattended-upgrades` for automatic security patches.
*   **Tooling**: Installs and configures **Mise** for version management, ensuring it's available system-wide.
*   **Shell**: Sets `zsh` as the default shell.

### macOS
*   **Homebrew**: Installs Homebrew if missing and bundles essential packages (`git`, `zsh`, `ffmpeg`, etc.).
*   **Tooling**: Installs **Mise** and runs `mise install`.

### Windows
*   **Tooling**: Installs **Mise** via `winget` and runs `mise install`.

## Shell & Terminal Configuration

The configuration is built around **Zsh** and focuses on speed and developer ergonomics.

### Core Components
*   **Plugin Manager**: Uses **Znap** for fast Zsh plugin loading and async compilation.
*   **Prompt**: **Powerlevel10k** for an informative and responsive interface.
*   **Environment**: **Mise** handles version management and environment variables.

### Navigation & File Management
*   **Zoxide**: Replaces `cd` with smart jumping (`z` command).
*   **Yazi**: Terminal file manager with shell integration (cwd changing via `y` alias).
*   **Eza**: Modern replacement for `ls` with icons and git status.
*   **Gtrash**: Safer alternative to `rm`. (alias: `del`)

### Development Workflow
*   **Git**: **Lazygit** integration and oh-my-zsh git plugin shorthands (e.g., `gcm`, `glg`, `gwip`).
*   **Node.js**: Extensive **pnpm** aliases for rapid development:
    *   `ni`: install
    *   `nr`: run
    *   `nidt`: install @types/<package>
    *   `nd`, `nb`, `nt`: dev, build, test
*   **Docker**: **Lazydocker** for container management.
*   **Completions**: **Carapace** provides binary-based completions for many tools.

## Technologies & Tools

Key tools and libraries used in this configuration:

*   **chezmoi**: Dotfile manager. https://chezmoi.io/
*   **mise**: Runtime executor and version manager. https://mise.jdx.dev/
*   **Zsh**: Interactive shell.
*   **Starship**: Cross-shell prompt (configuration available). https://starship.rs/
*   **Powerlevel10k**: Zsh theme. https://github.com/romkatv/powerlevel10k
*   **Znap**: Zsh plugin manager. https://github.com/marlonrichert/zsh-snap
*   **Yazi**: Terminal file manager. https://yazi-rs.github.io/
*   **Glow**: Markdown renderer for the terminal. https://github.com/charmbracelet/glow
*   **GitHub CLI (gh)**: GitHub command line tool.
*   **Rclone**: Command line program to manage files on cloud storage. https://rclone.org/
*   **Zoxide**: Smarter cd command. https://github.com/ajeetdsouza/zoxide
*   **Eza**: A modern, improved version of the ls command. https://eza.rocks/