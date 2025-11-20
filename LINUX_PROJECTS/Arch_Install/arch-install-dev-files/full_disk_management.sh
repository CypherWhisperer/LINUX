#!/bin/bash

# Function to display available disks
display_disks() {
  echo "Available disks:"
  lsblk -d -o NAME,SIZE,MODEL | grep -v 'loop'
}

# Function to display partitions on a selected disk
display_partitions() {
  local disk=$1
  echo "Partitions on /dev/$disk:"
  lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT /dev/$disk | grep -v 'loop'
}

# Function to get the file system type of a partition
get_fstype() {
  local partition=$1
  blkid -o value -s TYPE $partition
}

# Function to format partitions
format_partitions() {
  local boot=$1
  local root=$2
  local home=$3
  local swap=$4

  echo "Formatting partitions..."
  sudo mkfs.ext4 /dev/$boot
  sudo mkfs.ext4 /dev/$root
  if [ -n "$home" ]; then
    sudo mkfs.ext4 /dev/$home
  fi
  sudo mkswap /dev/$swap
}

# Function to calculate free space after shrinking
calculate_free_space() {
  local disk=$1
  local shrink_partition=$2
  local shrink_size=$3

  local total_size=$(lsblk -bno SIZE /dev/$disk)
  local used_size=$(lsblk -bno SIZE /dev/$shrink_partition)
  local shrink_size_bytes=$(numfmt --from=iec $shrink_size)
  local free_space=$(($total_size - $used_size + $shrink_size_bytes))

  echo $free_space
}

# Function to shrink partition
shrink_partition() {
  local disk=$1
  local partition=$2
  local fstype=$3
  local newsize=$4

  # Unmount the partition if it's mounted
  if mountpoint -q /dev/$partition; then
    echo "Unmounting /dev/$partition..."
    sudo umount /dev/$partition
    if [ $? -ne 0 ]; then
      echo "Error: Failed to unmount /dev/$partition !"
      exit 1
    fi
  fi

  # Check file system integrity
  echo "Checking file system integrity of /dev/$partition..."
  case $fstype in
    ext4|ext3|ext2)
      sudo e2fsck -f /dev/$partition
      ;;
    xfs)
      sudo xfs_repair /dev/$partition
      ;;
    btrfs)
      sudo btrfs check /dev/$partition
      ;;
    *)
      echo "Error: Unsupported file system type $fstype !"
      exit 1
      ;;
  esac
  if [ $? -ne 0 ]; then
    echo "Error: File system check failed on /dev/$partition !"
    exit 1
  fi

  # Resize the partition
  echo "Resizing /dev/$partition to $newsize..."
  sudo parted /dev/$disk --script resizepart $(echo $partition | grep -o '[0-9]*') $newsize
  if [ $? -ne 0 ]; then
    echo "Error: Failed to resize the partition !"
    exit 1
  fi

  # Resize the file system
  echo "Resizing file system on /dev/$partition..."
  case $fstype in
    ext4|ext3|ext2)
      sudo resize2fs /dev/$partition
      ;;
    xfs)
      sudo xfs_growfs /dev/$partition
      ;;
    btrfs)
      sudo btrfs filesystem resize $newsize /dev/$partition
      ;;
    *)
      echo "Error: Unsupported file system type $fstype."
      exit 1
      ;;
  esac
  if [ $? -ne 0 ]; then
    echo "Error: Failed to resize the file system."
    exit 1
  fi

  echo "Successfully resized /dev/$partition to $newsize."
}

# Function to partition the disk
partition_disk() {
  local disk=$1
  local free_space=$2
  local boot_size=$3
  local swap_size=$4
  local root_size=$5
  local separate_home=$6

  local required_space=$(($boot_size + $swap_size + $root_size))
  if [ "$separate_home" = true ]; then
    required_space=$(($required_space + $free_space))
  fi

  if [ $free_space -lt $required_space ]; then
    echo "Error: Not enough free space for the new partitions."
    exit 1
  fi

  # Start partitioning
  sudo parted /dev/$disk --script mklabel gpt

  # Create boot partition
  sudo parted /dev/$disk --script mkpart primary 1MiB ${boot_size}MiB
  sudo parted /dev/$disk --script set 1 boot on

  # Create swap partition
  sudo parted /dev/$disk --script mkpart primary ${boot_size}MiB $(($boot_size + $swap_size))MiB

  # Create root partition
  local root_end=$(($boot_size + $swap_size + $root_size))
  sudo parted /dev/$disk --script mkpart primary $(($boot_size + $swap_size))MiB ${root_end}MiB

  # Create home partition if separate
  if [ "$separate_home" = true ]; then
    local home_start=$root_end
    sudo parted /dev/$disk --script mkpart primary ${home_start}MiB 100%
  fi

  # Output partition layout
  echo "Boot: ${disk}1"
  echo "Swap: ${disk}2"
  echo "Root: ${disk}3"
  if [ "$separate_home" = true ]; then
    echo "Home: ${disk}4"
  fi
}

# Main script
main() {
  echo "Select setup:"
  echo "  1. I already have partitions ready."
  echo "  2. I am yet to partition the disk."

  read -p "Enter your choice (1 or 2): " setup_choice

  case $setup_choice in
    1)
      # Ask for existing partition details
      read -p "Enter the boot partition (e.g., sda1): " boot_partition
      read -p "Enter the root partition (e.g., sda2): " root_partition
      read -p "Enter the home partition (leave blank if none): " home_partition
      read -p "Enter the swap partition (e.g., sda3): " swap_partition

      # Format partitions
      format_partitions $boot_partition $root_partition $home_partition $swap_partition
      ;;
    2)
      echo "Select setup:"
      echo "  1. Use entire disk."
      echo "  2. Shrink an existing partition to install alongside."

      read -p "Enter your choice (1 or 2): " disk_setup_choice

      case $disk_setup_choice in
        1)
          # Partition entire disk
          display_disks
          read -p "Enter the disk to partition (e.g., sda): " disk
          display_partitions $disk

          read -p "Enter the size for the boot partition (in MiB, e.g., 512): " boot_size
          read -p "Enter the size for the swap partition (in MiB, e.g., 4096): " swap_size
          read -p "Enter the size for the root partition (in MiB, e.g., 30720): " root_size
          read -p "Do you want a separate home partition? (y/n): " separate_home_choice
          if [ "$separate_home_choice" = "y" ]; then
            separate_home=true
          else
            separate_home=false
          fi

          # Calculate free space on entire disk
          free_space=$(lsblk -bno SIZE /dev/$disk)
          partition_disk $disk $free_space $boot_size $swap_size $root_size $separate_home
          ;;
        2)
          # Shrink existing partition and then partition
          display_disks
          read -p "Enter the disk containing the partition to shrink (e.g., sda): " disk
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

          # Calculate free space
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

          partition_disk $disk $free_space $boot_size $swap_size $root_size $separate_home
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
}

main

