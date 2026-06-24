
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

    # Print wireless interfaces
    for i in "${!interfaces[@]}"; do
        echo "Interface $((i + 1)): ${interfaces[$i]}"
    done

    # Return the array of interfaces
    echo "${interfaces[@]}"
}

# Call the function and store the result in an array
wireless_interfaces=($(get_wireless_interfaces_iwconfig))

# Function to check if a network interface exists
check_interface_exists() {
    local interface=$1
    ip link show "$interface" >/dev/null 2>&1
    return $?
}

# Loop through the array and enable dhcpcd for each valid interface
for interface in "${wireless_interfaces[@]}"; do
    if check_interface_exists "$interface"; then
        echo "Enabling dhcpcd@$interface"
        # Uncomment the next line to enable the service
        # sudo systemctl enable --now dhcpcd@"$interface"
    else
        echo "Invalid interface: $interface"
    fi
done

