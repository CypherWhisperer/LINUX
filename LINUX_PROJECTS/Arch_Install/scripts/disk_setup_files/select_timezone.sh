#!/bin/bash

# Function to display the menu and get user selection
select_timezone() {
    echo "Select your Region:"
    select region in $(ls /usr/share/zoneinfo); do
        if [[ -d /usr/share/zoneinfo/$region ]]; then
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done

    echo "Select your City/Subzone:"
    select city in $(ls /usr/share/zoneinfo/$region); do
        if [[ -f /usr/share/zoneinfo/$region/$city ]]; then
            break
        else
            echo "Invalid selection. Please try again."
        fi
    done

    echo "You have selected: $region/$city"
    TIMEZONE="$region/$city"
}

# Run the function to select the timezone
select_timezone

# Check if the script is run inside chroot or live environment
if [[ $(readlink /etc/localtime) != "/usr/share/zoneinfo/$TIMEZONE" ]]; then
    ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
fi

# Set hardware clock to UTC
hwclock --systohc --utc

# Enable and start systemd-timesyncd (if using systemd)
systemctl enable systemd-timesyncd
systemctl start systemd-timesyncd
systemctl enable fstrim.timer

echo "Timezone set to $TIMEZONE"
