#!/bin/bash

# Get all network interfaces using ip link
get_all_interfaces() {
    # Extract interface names from ip link output
    interfaces=($(ip -o link show | awk -F': ' '{print $2}'))

    # Check if any interfaces were found
    if [ ${#interfaces[@]} -eq 0 ]; then
        echo "No network interfaces found."
        exit 1
    fi

    # Print network interfaces
    for i in "${!interfaces[@]}"; do
        echo "Interface $((i + 1)): ${interfaces[$i]}"
    done

    # Return the array of interfaces
    echo "${interfaces[@]}"
}

# Call the function and store the result in an array
network_interfaces=($(get_all_interfaces))

# Function to check if a network interface exists
check_interface_exists() {
    local interface=$1
    ip link show "$interface" >/dev/null 2>&1
    return $?
}

# Loop through the array and enable dhcpcd for each valid interface
for interface in "${network_interfaces[@]}"; do
    if check_interface_exists "$interface"; then
        echo "Enabling dhcpcd@$interface"
        # Uncomment the next line to enable the service
        # sudo systemctl enable --now dhcpcd@"$interface"
    else
        echo "Invalid interface: $interface"
    fi
done

