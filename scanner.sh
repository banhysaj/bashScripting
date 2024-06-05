#!/bin/bash

if [ ! -f "ips.txt" ]; then
    echo "Could not find file to read from"
    exit 1
fi

is_ip_reachable() {
    if ping -c 1 -W 1 "$1" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_certificate() {
    local ip=$1
    cert_info=$(echo | openssl s_client -connect $ip:443 -servername $ip -showcerts 2>/dev/null | openssl x509 -noout -issuer -text)

    # Check if certificate is valid and its strength
    cert_status=$(echo "$cert_info" | grep -q 'verify return:1' && echo "valid" || echo "invalid")
    cert_strength=$(echo "$cert_info" | grep -q 'Signature Algorithm: sha256' && echo "strong" || echo "weak")

    # Extract Issuer
    issuer=$(echo "$cert_info" | awk '/Issuer:/ {getline; print}')

    # If issuer is empty, set it to Unknown
    if [ -z "$issuer" ]; then
        issuer="Unknown"
    fi

    echo "$cert_status|$cert_strength|$issuer"
}

check_ports() {
    local ip=$1
    ports="80 22 21 20 443"
    port_status="secured"

    for port in $ports; do
        if ! nc -z -w5 $ip $port &>/dev/null; then
            port_status="unsecured"
            break
        fi
    done

    echo "$port_status"
}

check_server_headers() {
    local ip=$1
    headers=$(curl -sI $ip)

    header_status="valid"
    required_headers=("X-Content-Type-Options: nosniff" "Strict-Transport-Security" "Content-Security-Policy" "X-Frame-Options" "X-XSS-Protection")

    for header in "${required_headers[@]}"; do
        if ! echo "$headers" | grep -q "$header"; then
            header_status="invalid"
            break
        fi
    done

    echo "$header_status"
}

check_tls_protocols() {
    local ip=$1
    tls_status="secure"

    deprecated_protocols=("TLSv1" "TLSv1.1")
    for protocol in "${deprecated_protocols[@]}"; do
        if echo | openssl s_client -connect $ip:443 -servername $ip -$protocol 2>/dev/null | grep -q 'CONNECTED'; then
            tls_status="insecure"
            break
        fi
    done

    echo "$tls_status"
}

html_report="report.html"
echo "<html><head><title>Security Report</title></head><body><h1>Security Report</h1><table border='1'><tr><th>IP</th><th>Certificate</th><th>Certificate Strength</th><th>Issuer</th><th>Ports</th><th>Server</th><th>TLS</th><th>Can Enter Sensitive Info</th></tr>" > $html_report

text_report="result.txt"
echo "Security Report" > $text_report
echo "======================" >> $text_report

IFS=$'\n'
for ip in $(cat "ips.txt"); do
    echo "Scanning IP: $ip"

    if ! is_ip_reachable "$ip"; then
        echo "Unable to reach $ip"
        continue
    fi

    cert_result=$(check_certificate "$ip")
    cert_status=$(echo $cert_result | cut -d'|' -f1)
    cert_strength=$(echo $cert_result | cut -d'|' -f2)
    issuer=$(echo $cert_result | cut -d'|' -f3)

    port_status=$(check_ports "$ip")
    server_status=$(check_server_headers "$ip")
    tls_status=$(check_tls_protocols "$ip")

    if [ "$cert_status" = "valid" ] && [ "$cert_strength" = "strong" ] && [ "$port_status" = "secured" ] && [ "$server_status" = "valid" ] && [ "$tls_status" = "secure" ]; then
        sensitive_info="YES"
        color="green"
    else
        sensitive_info="NO"
        color="red"
    fi

    echo "<tr style='color:$color'><td>$ip</td><td>$cert_status</td><td>$cert_strength</td><td>$issuer</td><td>$port_status</td><td>$server_status</td><td>$tls_status</td><td>$sensitive_info</td></tr>" >> $html_report
    echo "IP: $ip" >> $text_report
    echo "Certificate: $cert_status" >> $text_report
    echo "Certificate Strength: $cert_strength" >> $text_report
    echo "Issuer: $issuer" >> $text_report
    echo "Ports: $port_status" >> $text_report
    echo "Server: $server_status" >> $text_report
    echo "TLS: $tls_status" >> $text_report
    echo "Can Enter Sensitive Info: $sensitive_info" >> $text_report
    echo "----------------------" >> $text_report

done

echo "</table></body></html>" >> $html_report

echo "Reports generated: $html_report and $text_report"
