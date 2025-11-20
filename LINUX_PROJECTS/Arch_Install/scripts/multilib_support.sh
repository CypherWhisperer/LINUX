#!/bin/bash

#Enabling multilib support for 32bit support

enable_multilib_support() {
    # Backup and temporary file paths
    backup_file="/etc/pacman.conf.backup"
    temp_file="/etc/pacman.conf.temp"
    original_file="/etc/pacman.conf"

    # Create a backup of pacman.conf if it doesn't exist
    if [ ! -f "$backup_file" ]; then
        sudo cp "$original_file" "$backup_file"
    fi

    # Copy pacman.conf to temp_file
    sudo cp "$original_file" "$temp_file"

    # Uncomment multilib repository and its Include directive in temp_file
    sudo sed -i '/^\[multilib\]/{s/^#//;n;s/^#//}' "$temp_file"
    sudo sed -i '/^Include = \/etc\/pacman\.d\/mirrorlist/{s/^#//}' "$temp_file"

    # Uncomment multilib-testing repository and its Include directive in temp_file
    sudo sed -i '/^\[multilib-testing\]/{s/^#//;n;s/^#//}' "$temp_file"
    sudo sed -i '/^Include = \/etc\/pacman\.d\/mirrorlist/{s/^#//}' "$temp_file"

    # Synchronize package databases using temp_file
    if sudo pacman -Sy --config "$temp_file"; then
        echo "Multilib support enabled successfully."
        # Replace original pacman.conf with temp_file
        sudo mv "$temp_file" "$original_file"
    else
        echo "Failed to synchronize package databases. Reverting changes."
        # Restore original pacman.conf from backup_file
        sudo cp "$backup_file" "$original_file"
        exit 1
    fi
}