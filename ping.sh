#!/bin/bash

read -p "Enter the URL to ping: " url

ip=$(ping -c 1 $url | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)

if [ -n "$ip" ]; then
echo "IP address of $url: $ip"
echo "$ip" >> ips.txt
echo "IP written to ips.txt"

else
echo "Failed to obtain IP address for $url"
fi

