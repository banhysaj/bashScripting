#!/bin/bash

# Update package lists
sudo apt-get update

# Install required packages
sudo apt-get install -y curl openssl nmap bc

echo "All required packages have been installed."
