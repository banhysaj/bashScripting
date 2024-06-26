#!/bin/bash

while true; do
    read -p "Enter the URL to ping (enter '0' to exit): " url

    if [ "$url" = "0" ]; then
        echo "Exiting..."
        break
    fi

    domain=$(echo "$url" | sed -e 's|http://||' -e 's|https://||')

    domain=$(echo "$domain" | cut -d'/' -f1)

    ip=$(ping -c 1 "$domain" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | head -n 1)

    if [ -n "$ip" ]; then
        echo "IP address of $url: $ip"
        echo "$ip" >> ips.txt
        echo "IP written to ips.txt"
    else
        echo "Failed to obtain IP address for $url"
    fi
done
