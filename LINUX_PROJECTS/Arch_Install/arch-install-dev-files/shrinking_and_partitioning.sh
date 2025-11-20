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
  display_disks

  # Ask user to select a disk
  read -p "Enter the disk to manage (e.g., sda): " disk
  if [ ! -b /dev/$disk ]; then
    echo "Error: /dev/$disk is not a valid disk."
    exit 1
  fi

  display_partitions $disk

  # Ask user if they want to shrink a partition
  read -p "Do you want to shrink a partition? (y/n): " shrink_choice
  if [ "$shrink_choice" = "y" ]; then
    # Ask user to select a partition
    read -p "Enter the partition to shrink (e.g., sda1): " partition
    if [ ! -b /dev/$partition ]; then
      echo "Error: /dev/$partition is not a valid partition."
      exit 1
    fi

    # Get the file system type
    fstype=$(get_fstype /dev/$partition)
    if [ -z "$fstype" ]; then
      echo "Error: Could not determine the file system type for /dev/$partition using blkid. Trying another method."
      fstype=$(sudo file -s /dev/$partition | awk '{print $2}')
      if [ -z "$fstype" ]; then
        echo "Error: Could not determine the file system type for /dev/$partition."
        exit 1
      fi
    fi
    echo "File system type for /dev/$partition: $fstype"

    # Ask user for new size
    read -p "Enter the new size (e.g., 50G): " newsize

    # Calculate free space after shrinking
    free_space=$(calculate_free_space $disk $partition $newsize)
    if [ $free_space -le 0 ]; then
      echo "Error: Not enough free space after shrinking."
      exit 1
    fi

    # Shrink the partition
    shrink_partition $disk $partition $fstype $newsize
  else
    # Get total free space on the disk
    free_space=$(lsblk -bno SIZE /dev/$disk)
  fi

  # Ask user for partition sizes
  read -p "Enter the size for the boot partition (e.g., 512): " boot_size
  read -p "Enter the size for the swap partition (e.g., 4096): " swap_size
  read -p "Enter the size for the root partition (e.g., 30720): " root_size
  read -p "Do you want a separate home partition? (y/n): " separate_home_choice
  if [ "$separate_home_choice" = "y" ]; then
    separate_home=true
  else
    separate_home=false
  fi

  # Partition the disk
  partition_disk $disk $free_space $boot_size $swap_size $root_size $separate_home
}

main

