#!/bin/bash
# (c) 2025 - FlameIT - Immersion Cooling
# Paweł 'felixd' Wojciechowski
# https://www.flameit.io
# `arp` -> mac - vendor - ip

# -----------------------------------------------------------------------------
# Script: arp_mac_vendor_ip.sh
# Description:
#   This script collects and displays ARP table entries in a formatted table,
#   including the MAC address, IP address, and the vendor associated with each 
#   MAC address based on the IEEE OUI database.
#
# Use Case:
#   Network administrators can use this script to quickly identify devices 
#   connected to a local network. By matching MAC addresses to vendor names,
#   the script helps in device identification and network troubleshooting.
#
# Functionality:
#   - Fetches MAC and IP address pairs from the local ARP cache.
#   - Matches MAC address prefixes to vendors using a locally cached OUI database.
#   - Sorts the results based on MAC address, IP address, or vendor.
#   - Displays a neatly formatted table of results.
# -----------------------------------------------------------------------------

# Path to the converted OUI database
OUI_FILE="./oui_converted.txt"

# Check for sorting arguments (default: sort by MAC)
SORT_BY="mac"
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

# Download and convert the IEEE OUI database if it does not exist locally
if ! [ -f "$OUI_FILE" ]; then
    echo "Downloading latest IEEE OUI Vendor Database"
    curl -O https://standards-oui.ieee.org/oui/oui.txt
    sed -i 's/\r$//' oui.txt
    awk '/\(hex\)/ {
        gsub("-", ":", $1);
        prefix = toupper($1);
        vendor = "";
        for (i=3; i<=NF; i++) {
            vendor = vendor " " $i;
        }
        gsub(/^[ ]+/, "", vendor);
        print prefix, vendor;
    }' oui.txt > "$OUI_FILE"
    rm oui.txt
fi

# Function: get_vendor_local
# Purpose: Given a MAC address, return the associated vendor name using the local OUI file.
get_vendor_local() {
    local mac=$1
    local prefix=$(echo "$mac" | awk -F: '{printf "%s:%s:%s", toupper($1), toupper($2), toupper($3)}')
    vendor=$(grep -i "^$prefix" "$OUI_FILE" | head -n1 | cut -d' ' -f2-)
    if [ -z "$vendor" ]; then
        vendor="Unknown Vendor"
    fi
    echo "$vendor"
}

# Collect ARP data into an array for processing
data=()
while read -r mac ip; do
    if [[ -z "$mac" || "$mac" == "(incomplete)" ]]; then
        continue
    fi
    vendor=$(get_vendor_local "$mac")
    data+=("$mac|$ip|$vendor")
done < <(arp -an | awk '/..:..:..:..:..:../ {print $4, $2}' | tr -d '()')

# Sort data according to the selected sorting method
case "$SORT_BY" in
    mac)
        sorted_data=$(printf "%s\n" "${data[@]}" | sort -t'|' -k1)
        ;;
    ip)
        # Convert IP addresses to zero-padded format for correct sorting, then revert
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

# Display sorted ARP data
printf "%s\n" "$sorted_data" | while IFS='|' read -r mac ip vendor; do
    printf "| %-17s | %-15s | %-50s |\n" "$mac" "$ip" "$vendor"
done
printf "|-------------------|-----------------|----------------------------------------------------|\n"
