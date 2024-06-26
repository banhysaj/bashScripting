#!/bin/bash

if [ ! -f "ips.txt" ]; then
    echo "Could not find file to read from"
    exit 1
fi

is_ip_reachable() {
    if curl --connect-timeout 5 --silent "http://$1" >/dev/null; then
        return 0
    else
        return 1
    fi
}

check_certificate() {
    local ip=$1
    local temp_cert_file=$(mktemp)

    echo | openssl s_client -connect "$ip:443" -servername "$ip" 2>/dev/null | openssl x509 -out "$temp_cert_file" -noout -dates
    
    if [ $? -ne 0 ]; then
        echo "invalid"
        rm -f "$temp_cert_file"
        return
    fi

    start_date=$(grep 'notBefore' "$temp_cert_file" | cut -d= -f2)
    end_date=$(grep 'notAfter' "$temp_cert_file" | cut -d= -f2)

    start_date_seconds=$(date -d "$start_date" +%s)
    end_date_seconds=$(date -d "$end_date" +%s)
    current_date_seconds=$(date +%s)

    rm -f "$temp_cert_file"

    if [ "$current_date_seconds" -ge "$start_date_seconds" ] && [ "$current_date_seconds" -le "$end_date_seconds" ]; then
        echo "valid"
    else
        echo "invalid"
    fi
}

check_ports() {
    local ip=$1
    ports="80 22 21 20 443"
    port_status="secured"

    for port in $ports; do
        if ! nc -z -w5 "$ip" "$port" &>/dev/null; then
            port_status="unsecured"
            break
        fi
    done

    echo "$port_status"
}

check_server_response_time() {
    local ip=$1
    response_time=$(curl -o /dev/null -s -w "%{time_total}\n" "https://$ip")

    threshold=2.0

    if (( $(echo "$response_time < $threshold" | bc -l) )); then
        echo "valid"
    else
        echo "invalid"
    fi
}

check_tls_protocols() {
    local ip=$1
    tls_status="secure"

    deprecated_protocols=("TLSv1" "TLSv1.1")
    for protocol in "${deprecated_protocols[@]}"; do
        if echo | openssl s_client -connect "$ip:443" -servername "$ip" -"$protocol" 2>/dev/null | grep -q 'CONNECTED'; then
            tls_status="insecure"
            break
        fi
    done

    echo "$tls_status"
}

perform_nmap_scan() {
    local ip=$1
    
    nmap_output=$(nmap -sV --script vulners "$ip" -oX -)

    if echo "$nmap_output" | grep -q "CVE"; then
        echo "Found"
    else
        echo "none"
    fi
}

read -p "Do you want to scan for vulnerabilities? (y/n): " scan_vulnerabilities

if [[ "$scan_vulnerabilities" == "y" || "$scan_vulnerabilities" == "Y" ]]; then
    include_vulnerabilities="yes"
elif [[ "$scan_vulnerabilities" == "n" || "$scan_vulnerabilities" == "N" ]]; then
    include_vulnerabilities="no"
else
    echo "Invalid input. Exiting."
    exit 1
fi

html_report="report.html"
echo "<html><head><title>Security Report</title></head><body><h1>Security Report</h1><table border='1'><tr><th>IP</th><th>Certificate</th><th>Ports</th><th>Server</th><th>TLS</th>" > "$html_report"

text_report="result.txt"
if [ ! -f "$text_report" ]; then
    echo "Security Report" > "$text_report"
    echo "======================" >> "$text_report"
fi

if [ "$include_vulnerabilities" == "yes" ]; then
    echo "<th>Vulnerabilities</th>" >> "$html_report"
    echo "Vulnerabilities" >> "$text_report"
fi

echo "<th>Can Enter Sensitive Info</th></tr>" >> "$html_report"

IFS=$'\n'
for ip in $(cat "ips.txt"); do
    echo "Scanning IP: $ip"

    if ! is_ip_reachable "$ip"; then
        echo "Unable to reach $ip"
        continue
    fi

    cert_status=$(check_certificate "$ip")
    port_status=$(check_ports "$ip")
    server_status=$(check_server_response_time "$ip")
    tls_status=$(check_tls_protocols "$ip")

    if [ "$include_vulnerabilities" == "yes" ]; then
        vuln_status=$(perform_nmap_scan "$ip")
    else
        vuln_status="N/A"
    fi

    if [ "$cert_status" = "valid" ] && [ "$port_status" = "secured" ] && [ "$server_status" = "valid" ] && [ "$tls_status" = "secure" ]; then
        sensitive_info="YES"
        color="green"
    else
        sensitive_info="NO"
        color="red"
    fi

    cat <<EOF >> "$html_report"
<tr style='color:$color'>
<td>$ip</td>
<td>$cert_status</td>
<td>$port_status</td>
<td>$server_status</td>
<td>$tls_status</td>
EOF

    if [ "$include_vulnerabilities" == "yes" ]; then
        echo "<td>$vuln_status</td>" >> "$html_report"
    fi

    echo "<td>$sensitive_info</td>" >> "$html_report"
    echo "</tr>" >> "$html_report"

    echo "IP: $ip" >> "$text_report"
    echo "Certificate: $cert_status" >> "$text_report"
    echo "Ports: $port_status" >> "$text_report"
    echo "Server: $server_status" >> "$text_report"
    echo "TLS: $tls_status" >> "$text_report"
    
    if [ "$include_vulnerabilities" == "yes" ]; then
        echo "Vulnerabilities: $vuln_status" >> "$text_report"
    fi
    
    echo "Can Enter Sensitive Info: $sensitive_info" >> "$text_report"
    echo "----------------------" >> "$text_report"
done

echo "</table></body></html>" >> "$html_report"

echo "Reports generated: $html_report and $text_report"
