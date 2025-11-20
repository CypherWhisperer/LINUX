#!/bin/bash


##### ------------> CHATGPT CONVO: Specify Backup Device for Timeshift -------------> DATE: 11/7/2024 

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
          # Partition the entire disk
          read -p "Enter the size for the boot partition (in MiB, e.g., 512): " boot_size
          read -p "Enter the size for the swap partition (in MiB, e.g., 4096): " swap_size
          read -p "Enter the size for the root partition (in MiB, e.g., 30720): " root_size
          read -p "Do you want a separate home partition? (y/n): " separate_home_choice
          if [ "$separate_home_choice" = "y" ]; then
            separate_home=true
          else
            separate_home=false
          fi

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
