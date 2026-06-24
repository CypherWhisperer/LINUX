#!/bin/bash

# Source the other script files
source disk_operations.sh
source partition_operations.sh
source filesystem_operations.sh

# Main script
main() {
  display_disks

  # Ask user to select a setup type
  echo "Select setup:"
  echo "1. I already have partitions ready."
  echo "2. I am yet to partition the disk."
  read -p "Enter your choice: " setup_choice

  case $setup_choice in
    1)
      # Ask for partitions
      read -p "Enter the boot partition (e.g., sda1): " boot_partition
      read -p "Enter the root partition (e.g., sda2): " root_partition
      read -p "Enter the home partition (leave empty if not applicable, e.g., sda3): " home_partition
      read -p "Enter the swap partition (e.g., sda4): " swap_partition

      # Format partitions
      partitions=$(format_partitions $boot_partition $root_partition $home_partition $swap_partition)
      ;;
    2)
      display_disks

      # Ask user to select a disk
      read -p "Enter the disk to manage (e.g., sda): " disk
      if [ ! -b /dev/$disk ]; then
        echo "Error: /dev/$disk is not a valid disk."
        exit 1
      fi

      echo "Which setup would you like?"
      echo "1. Use entire disk."
      echo "2. Shrinking an existing partition to install alongside."
      read -p "Enter your choice: " partition_choice

      case $partition_choice in
        1)
          # Ask for partition sizes
          read -p "Enter the size for the boot partition (in MiB, e.g., 512): " boot_size
          read -p "Enter the size for the swap partition (in MiB, e.g., 4096): " swap_size
          read -p "Enter the size for the root partition (in MiB, e.g., 30720): " root_size
          read -p "Do you want a separate home partition? (y/n): " separate_home_choice
          if [ "$separate_home_choice" = "y" ]; then
            separate_home=true
          else
            separate_home=false
          fi

          # Partition the entire disk
          partitions=$(partition_disk $disk 0 $boot_size $swap_size $root_size $separate_home)
          ;;
        2)
          display_partitions $disk

          # Ask user to select a partition to shrink
          read -p "Enter the partition to shrink (e.g., sda1): " shrink_partition
          if [ ! -b /dev/$shrink_partition ]; then
            echo "Error: /dev/$shrink_partition is not a valid partition."
            exit 1
          fi

          # Get the file system type
          fstype=$(get_fstype /dev/$shrink_partition)
          if [ -z "$fstype" ]; then
            echo "Error: Could not determine the file system type for /dev/$shrink_partition using blkid. Trying another method."
            fstype=$(sudo file -s /dev/$shrink_partition | awk '{print $2}')
            if [ -z "$fstype" ]; then
              echo "Error: Could not determine the file system type for /dev/$shrink_partition."
              exit 1
            fi
          fi
          echo "File system type for /dev/$shrink_partition: $fstype"

          # Ask user for new size
          read -p "Enter the new size (e.g., 50GB): " newsize

          # Calculate free space after shrinking
          free_space=$(calculate_free_space $disk $shrink_partition $newsize)
          if [ $? -ne 0 ]; then
            echo "Error: Failed to calculate free space."
            exit 1
          fi

          # Shrink the partition
          shrink_partition $disk $shrink_partition $fstype $newsize

          # Partition the free space
          read -p "Enter the size for the boot partition (in MiB, e.g., 512): " boot_size
          read -p "Enter the size for the swap partition (in MiB, e.g., 4096): " swap_size
          read -p "Enter the size for the root partition (in MiB, e.g., 30720): " root_size
          read -p "Do you want a separate home partition? (y/n): " separate_home_choice
          if [ "$separate_home_choice" = "y" ]; then
            separate_home=true
          else
            separate_home=false
          fi

          partitions=$(partition_disk $disk $free_space $boot_size $swap_size $root_size $separate_home)
          ;;
        *)
          echo "Invalid choice."
          exit 1
          ;;
      esac
      ;;
    *)
      echo "Invalid choice."
      exit 1
      ;;
  esac

  # Extract the partitions from the formatted string
  IFS=' ' read -r boot_partition root_partition home_partition swap_partition <<< "$partitions"

  # Mount the partitions
  mount_partitions $boot_partition $root_partition $home_partition $swap_partition

  echo "Partitions mounted successfully. Ready for Arch Linux installation."
}

main
