#!/bin/bash

# Get wireless interfaces using iwconfig
get_wireless_interfaces_iwconfig() {
    # Extract interface names from iwconfig output
    interfaces=($(iwconfig 2>/dev/null | grep '^[a-zA-Z0-9]' | awk '{print $1}'))

    # Check if any wireless interfaces were found
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo "No wireless interfaces found."
        exit 1
    fi

    # Print and store wireless interfaces
    for i in "${!interfaces[@]}"; do
        echo "iwconfig ..... "
        echo "Interface $((i + 1)): ${interfaces[$i]}"
        eval "interface_$((i + 1))=${interfaces[$i]}"
    done
}

# Call the function
get_wireless_interfaces_iwconfig


# Get wireless interfaces using nmcli
get_wireless_interfaces_nmcli() {
    # Extract interface names from nmcli device output
    interfaces=($(nmcli device status | grep 'wifi' | awk '{print $1}'))

    # Check if any wireless interfaces were found
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo "No wireless interfaces found."
        exit 1
    fi

    # Print and store wireless interfaces
    for i in "${!interfaces[@]}"; do
        echo "nmcli ....."
        echo "Interface $((i + 1)): ${interfaces[$i]}"
        eval "interface_$((i + 1))=${interfaces[$i]}"
    done
}

# Call the function
get_wireless_interfaces_nmcli

