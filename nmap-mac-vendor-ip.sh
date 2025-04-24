#!/bin/bash
# (c) 2025 - FlameIT - Immersion Cooling
# Paweł 'felixd' Wojciechowski
# https://www.flameit.io
# `nmap` -> mac - vendor - ip

# -----------------------------------------------------------------------------
# Script: nmap_mac_vendor_ip.sh
# Description:
#   This script uses nmap to discover devices on the local network, extracting
#   MAC addresses, IP addresses, and associated vendor information.
#
# Use Case:
#   Useful for network administrators to identify devices and troubleshoot
#   local network issues with minimal setup.
#
# Functionality:
#   - Scans the local network using nmap.
#   - Extracts MAC addresses, IP addresses, and vendors from nmap output.
#   - Sorts the results based on MAC address, IP address, or vendor.
#   - Displays a formatted table of results.
# -----------------------------------------------------------------------------

# Check for sorting arguments (default: sort by MAC)
SORT_BY="ip"
for arg in "$@"; do
    case $arg in
        --sort=mac)
            SORT_BY="mac"
            ;;
        --sort=ip)
            SORT_BY="ip"
            ;;
        --sort=vendor)
            SORT_BY="vendor"
            ;;
        *)
            echo "Usage: $0 [--sort=mac|ip|vendor]"
            exit 1
            ;;
    esac
done

# Detect the local network range (assumes eth0 or similar, adjust if needed)
NETWORK_RANGE=$(ip route | awk '/default/ {print $3}' | xargs -I{} ip route get {} | awk '{print $1"/24"; exit}')

# Scan the network
echo "Scanning the network $NETWORK_RANGE using nmap..."
NMAP_OUTPUT=$(nmap -sn "$NETWORK_RANGE")

# Parse nmap output
# nmap -sn gives lines like:
# Nmap scan report for 192.168.1.10
# Host is up (0.0050s latency).
# MAC Address: 00:11:22:33:44:55 (Vendor Name)

data=()
current_ip=""
while IFS= read -r line; do
    if [[ $line == "Nmap scan report for"* ]]; then
        current_ip=$(echo $line | awk '{print $5}')
    elif [[ $line == "MAC Address:"* ]]; then
        mac=$(echo $line | awk '{print $3}')
        vendor=$(echo "$line" | cut -d'(' -f2 | tr -d ')')
        data+=("$mac|$current_ip|$vendor")
    fi
done <<< "$NMAP_OUTPUT"

# Sort data according to the selected sorting method
case "$SORT_BY" in
    mac)
        sorted_data=$(printf "%s\n" "${data[@]}" | sort -t'|' -k1)
        ;;
    ip)
        sorted_data=$(printf "%s\n" "${data[@]}" | awk -F'|' '{ split($2, ip, "."); printf "%03d.%03d.%03d.%03d|%s|%s\n", ip[1], ip[2], ip[3], ip[4], $1, $3 }' | sort -t'.' -k1,1n -k2,2n -k3,3n -k4,4n | awk -F'|' '{ split($1, ip, "."); printf "%s|%d.%d.%d.%d|%s\n", $2, ip[1], ip[2], ip[3], ip[4], $3 }')
        ;;
    vendor)
        sorted_data=$(printf "%s\n" "${data[@]}" | sort -t'|' -k3)
        ;;
esac

# Display table header
printf "|-------------------|-----------------|----------------------------------------------------|\n"
printf "| %-17s | %-15s | %-50s |\n" "MAC Address" "IP" "Vendor"
printf "|-------------------|-----------------|----------------------------------------------------|\n"

# Display sorted data
printf "%s\n" "$sorted_data" | while IFS='|' read -r mac ip vendor; do
    printf "| %-17s | %-15s | %-50s |\n" "$mac" "$ip" "$vendor"
done
printf "|-------------------|-----------------|----------------------------------------------------|\n"
