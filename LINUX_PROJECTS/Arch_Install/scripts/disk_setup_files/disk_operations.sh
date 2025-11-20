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
