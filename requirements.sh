#!/bin/bash

sudo apt-get update

sudo apt-get install -y curl openssl nmap bc git

cd /usr/share/nmap/scripts/

sudo git clone https://github.com/vulnersCom/Nmap-vulners.git

sudo chmod +x Nmap-vulners/vulners.nse

if ! command -v nmap &> /dev/null; then
    echo "Error: nmap installation failed or not found."
    exit 1
fi

if [ ! -f "/usr/share/nmap/scripts/Nmap-vulners/vulners.nse" ]; then
    echo "Error: vulners script installation failed or not found."
    exit 1
fi

echo "All required packages and scripts have been installed."
