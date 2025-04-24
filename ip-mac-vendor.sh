#!/bin/bash
# (c) 2025 - FlameIT - Immersion Cooling - Paweł 'felixd' Wojciechowski
# `arp` -> mac - vendor - ip

# Ścieżka do przekonwertowanej bazy OUI
OUI_FILE="./oui_converted.txt"

# Sprawdź argumenty
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
            echo "Użycie: $0 [--sort=mac|ip|vendor]"
            exit 1
            ;;
    esac
done

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

get_vendor_local() {
    local mac=$1
    local prefix=$(echo "$mac" | awk -F: '{printf "%s:%s:%s", toupper($1), toupper($2), toupper($3)}')
    vendor=$(grep -i "^$prefix" "$OUI_FILE" | head -n1 | cut -d' ' -f2-)
    if [ -z "$vendor" ]; then
        vendor="Unknown Vendor"
    fi
    echo "$vendor"
}

# Zbieranie danych do tablicy
data=()
while read -r mac ip; do
    if [[ -z "$mac" || "$mac" == "(incomplete)" ]]; then
        continue
    fi
    vendor=$(get_vendor_local "$mac")
    data+=("$mac|$ip|$vendor")
done < <(arp -an | awk '/..:..:..:..:..:../ {print $4, $2}' | tr -d '()')

# Sortowanie danych z poprawnym sortowaniem IP
case "$SORT_BY" in
    mac)
        sorted_data=$(printf "%s\n" "${data[@]}" | sort -t'|' -k1)
        ;;
    ip)
        # Dodajemy numerację IP do tymczasowego sortowania
        sorted_data=$(printf "%s\n" "${data[@]}" | awk -F'|' '{ split($2, ip, "."); printf "%03d.%03d.%03d.%03d|%s|%s\n", ip[1], ip[2], ip[3], ip[4], $1, $3 }' | sort -t'.' -k1,1n -k2,2n -k3,3n -k4,4n | awk -F'|' '{ split($1, ip, "."); printf "%s|%d.%d.%d.%d|%s\n", $2, ip[1], ip[2], ip[3], ip[4], $3 }')
        ;;
    vendor)
        sorted_data=$(printf "%s\n" "${data[@]}" | sort -t'|' -k3)
        ;;
esac

# Nagłówek
printf "|-------------------|-----------------|----------------------------------------------------|\n"
printf "| %-17s | %-15s | %-50s |\n" "MAC Address" "IP" "Vendor"
printf "|-------------------|-----------------|----------------------------------------------------|\n"

# Wyświetlenie posortowanych danych
printf "%s\n" "$sorted_data" | while IFS='|' read -r mac ip vendor; do
    printf "| %-17s | %-15s | %-50s |\n" "$mac" "$ip" "$vendor"
done
printf "|-------------------|-----------------|----------------------------------------------------|\n"
