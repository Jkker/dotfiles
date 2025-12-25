#!/bin/bash
sudo apt-get install software-properties-common -y
sudo add-apt-repository --yes ppa:fish-shell/release-4
sudo apt-get update
sudo apt-get install fish -y
fish --version

# install fisher
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
