#!/bin/bash

install_de_wm() {
    echo "Choose one or more Desktop Environments or Window Managers to install:"
    echo "1) GNOME"
    echo "2) KDE Plasma"
    echo "3) Xfce"
    echo "4) LXQt"
    echo "5) Cinnamon"
    echo "6) MATE"
    echo "7) Deepin"
    echo "8) i3"
    echo "9) Hyprland"
    echo "10) Qtile"
    echo "11) Minimal Arch (install neither)"
    echo
    read -p "Enter your choices (separate by space, e.g., 1 2 9): " choices

    for choice in $choices; do
        case $choice in
            1)
                read -p "Install minimal GNOME? (y/n): " minimal
                if [[ $minimal == "y" ]]; then
                    echo "Installing minimal GNOME..."
                    sudo pacman -S --noconfirm gnome-shell gdm gnome-terminal nautilus
                else
                    echo "Installing full GNOME..."
                    sudo pacman -S --noconfirm gnome gnome-extra
                fi
                ;;
            2)
                read -p "Install minimal KDE Plasma? (y/n): " minimal
                if [[ $minimal == "y" ]]; then
                    echo "Installing minimal KDE Plasma..."
                    sudo pacman -S --noconfirm plasma-desktop konsole dolphin
                else
                    echo "Installing full KDE Plasma..."
                    sudo pacman -S --noconfirm plasma kde-applications
                fi
                ;;
            3)
                read -p "Install minimal Xfce? (y/n): " minimal
                if [[ $minimal == "y" ]]; then
                    echo "Installing minimal Xfce..."
                    sudo pacman -S --noconfirm xfce4 xfce4-terminal thunar
                else
                    echo "Installing full Xfce..."
                    sudo pacman -S --noconfirm xfce4 xfce4-goodies
                fi
                ;;
            4)
                echo "Installing LXQt..."
                sudo pacman -S --noconfirm lxqt
                ;;
            5)
                echo "Installing Cinnamon..."
                sudo pacman -S --noconfirm cinnamon
                ;;
            6)
                echo "Installing MATE..."
                sudo pacman -S --noconfirm mate mate-extra
                ;;
            7)
                echo "Installing Deepin..."
                sudo pacman -S --noconfirm deepin deepin-extra
                ;;
            8)
                echo "Installing i3..."
                sudo pacman -S --noconfirm i3
                ;;
            9)
                echo "Installing Hyprland..."
                # Assuming Hyprland installation from AUR
                git clone https://aur.archlinux.org/hyprland.git
                cd hyprland
                makepkg -si --noconfirm
                cd ..
                rm -rf hyprland
                ;;
            10)
                echo "Installing Qtile..."
                sudo pacman -S --noconfirm qtile
                ;;
            11)
                echo "Minimal Arch selected. No DE or WM will be installed."
                ;;
            *)
                echo "Invalid choice: $choice"
                ;;
        esac
    done

    echo "Installation complete."
}

# Call the function
install_de_wm

#!/bin/bash

create_timeshift_snapshot() {
    # Get the root and backup partitions from the user
    read -p "Enter the root partition (e.g., /dev/sda1): " root_partition
    read -p "Enter the backup partition (e.g., /dev/sda2): " backup_partition

    # Mount the root partition
    mount $root_partition /mnt
    if [ $? -ne 0 ]; then
        echo "Error mounting root partition."
        return 1
    fi

    # Bind necessary directories
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    mount --bind /run /mnt/run

    # Chroot into the mounted system
    arch-chroot /mnt /bin/bash <<EOF
# Mount the backup partition
mkdir -p /mnt/backup
mount $backup_partition /mnt/backup
if [ $? -ne 0 ]; then
    echo "Error mounting backup partition."
    exit 1
fi

# Install Timeshift if not already installed
pacman -Sy --noconfirm timeshift

# Create the Timeshift snapshot
timeshift --create --comments "Initial backup" --tags D --snapshot-device /mnt/backup
if [ $? -ne 0 ]; then
    echo "Error creating Timeshift snapshot."
    exit 1
fi

# Unmount the backup partition
umount /mnt/backup
EOF

    # Unmount the bound directories
    umount /mnt/dev
    umount /mnt/proc
    umount /mnt/sys
    umount /mnt/run

    # Unmount the root partition
    umount /mnt

    echo "Timeshift snapshot creation complete."
}

# Call the function
create_timeshift_snapshot
#!/bin/bash

# Function to separate pacman and AUR packages
separate_packages() {
    local package_list_file="$1"
    local pacman_list_file="$2"
    local aur_list_file="$3"

    # Clear the output files if they exist
    > "$pacman_list_file"
    > "$aur_list_file"

    # Read the package list file line by line
    while IFS= read -r package; do
        if [[ -n "$package" ]]; then
            # Check if the package is available in the official repositories
            if pacman -Si "$package" &>/dev/null; then
                echo "$package" >> "$pacman_list_file"
            else
                echo "$package" >> "$aur_list_file"
            fi
        fi
    done < "$package_list_file"

    echo "Packages have been separated into $pacman_list_file and $aur_list_file."
}

# Example usage:
# separate_packages "packages.txt" "pacman_packages.txt" "aur_packages.txt"

# Uncomment the line below to run the function with your package list file
# separate_packages "path/to/your/package_list.txt" "pacman_packages.txt" "aur_packages.txt"


