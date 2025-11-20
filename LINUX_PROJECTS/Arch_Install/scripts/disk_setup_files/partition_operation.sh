#!/bin/bash

# Function to calculate free space after shrinking a partition
calculate_free_space() {
  local disk=$1
  local shrink_partition=$2
  local shrink_size=$3

  # Total size of the disk in bytes
  local total_size=$(lsblk -bno SIZE /dev/$disk)
  # Used size of the partition to shrink in bytes
  local used_size=$(lsblk -bno SIZE /dev/$shrink_partition)
  # Convert the desired shrink size to bytes
  local shrink_size_bytes=$(numfmt --from=iec $shrink_size)
  # Sum of all partition sizes in bytes, excluding the total disk size: sum of all patitions on the disk
  local used_by_all_partitions=$(lsblk -bno SIZE /dev/$disk* | grep -v "^$total_size$" | paste -sd+ - | bc)
  # Calculate the free space on the disk after shrinking including 
  #the space freed by shrinking the partition and any existing free space on the disk
  local free_space=$(($total_size - $used_by_all_partitions + $used_size - $shrink_size_bytes))

  echo $free_space
}

# Function to shrink a partition
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
      echo "Error: Failed to unmount /dev/$partition!"
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
      echo "Error: Unsupported file system type $fstype!"
      exit 1
      ;;
  esac
  if [ $? -ne 0 ]; then
    echo "Error: File system check failed on /dev/$partition!"
    exit 1
  fi

  # Resize the partition
  echo "Resizing /dev/$partition to $newsize..."
  sudo parted /dev/$disk --script resizepart $(echo $partition | grep -o '[0-9]*') $newsize
  if [ $? -ne 0 ]; then
    echo "Error: Failed to resize the partition!"
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

# Function to partition a disk
partition_disk() {
  local disk=$1
  local free_space=$2
  local boot_size=$3
  local swap_size=$4
  local root_size=$5
  local separate_home=$6

  # Calculate sizes in MiB
  free_space_mib=$(($free_space / 1024 / 1024))
  boot_size_mib=$boot_size
  swap_size_mib=$swap_size
  root_size_mib=$root_size

  if [ "$separate_home" = true ]; then
    home_size_mib=$(($free_space_mib - $boot_size_mib - $swap_size_mib - $root_size_mib))
    if [ $home_size_mib -le 0 ]; then
      echo "Error: Not enough free space to create separate home partition."
      exit 1
    fi
  else
    home_size_mib=0
  fi

  # Create partitions
  echo "Creating boot partition..."
  sudo parted /dev/$disk --script mkpart primary fat32 1MiB ${boot_size_mib}MiB
  boot_partition="${disk}1"
  echo "Creating swap partition..."
  sudo parted /dev/$disk --script mkpart primary linux-swap ${boot_size_mib}MiB $(($boot_size_mib + $swap_size_mib))MiB
  swap_partition="${disk}2"
  echo "Creating root partition..."
  sudo parted /dev/$disk --script mkpart primary ext4 $(($boot_size_mib + $swap_size_mib))MiB $(($boot_size_mib + $swap_size_mib + $root_size_mib))MiB
  root_partition="${disk}3"

  if [ "$separate_home" = true ]; then
    echo "Creating home partition..."
    sudo parted /dev/$disk --script mkpart primary ext4 $(($boot_size_mib + $swap_size_mib + $root_size_mib))MiB 100%
    home_partition="${disk}4"
  else
    home_partition=""
  fi

  echo "$boot_partition $root_partition $home_partition $swap_partition"
}
