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

  # Ask user to select a partition
  read -p "Enter the partition to resize (e.g., sda1): " partition
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
  read -p "Enter the new size (e.g., 50GB): " newsize

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

main

