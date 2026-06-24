#!/bin/bash

# Function to format partitions
format_partitions() {
  local boot_partition=$1
  local root_partition=$2
  local home_partition=$3
  local swap_partition=$4

  echo "Formatting boot partition..."
  sudo mkfs.fat -F32 /dev/$boot_partition
  echo "Formatting root partition..."
  sudo mkfs.ext4 /dev/$root_partition
  if [ -n "$home_partition" ]; then
    echo "Formatting home partition..."
    sudo mkfs.ext4 /dev/$home_partition
  fi
  echo "Setting up swap partition..."
  sudo mkswap /dev/$swap_partition
  sudo swapon /dev/$swap_partition

  echo "$boot_partition $root_partition $home_partition $swap_partition"
}

# Function to mount partitions
mount_partitions() {
  local boot_partition=$1
  local root_partition=$2
  local home_partition=$3
  local swap_partition=$4

  echo "Mounting root partition..."
  sudo mount /dev/$root_partition /mnt
  echo "Creating and mounting boot partition..."
  sudo mkdir -p /mnt/boot/efi
  sudo mount /dev/$boot_partition /mnt/boot/efi
  if [ -n "$home_partition" ]; then
    echo "Creating and mounting home partition..."
    sudo mkdir -p /mnt/home
    sudo mount /dev/$home_partition /mnt/home
  fi

  echo "Partitions mounted successfully."
}
