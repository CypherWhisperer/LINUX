#!/bin/bash

#consider (#!/usr/bin/env bash)

#DISK AND PARTITIONING

####--------------------------------> SOURCED FILE HERE --------------------------------------->

#CONNECTING TO THE INTERNET 

#### -------------------------------> SOURCED FILE HERE -------------------------------------->

#MIRRORLIST MANAGEMENT
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
pacman -Sy pacman-contrib
rankmirrors -n 10 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist

###---------> CONSIDER MAKING IT SOMEWHAT OPTIONAL DUE TO SOME CASES WHERE IT IS SLOW --------------->

#INSTALLING THE BASE SYSTEM
pacstrap -K /mnt base linux linux-firmware base-devel

#--------------> CONSIDER A FUNCTION TO TAKE IN MORE PACKAGES AND HAVE THESE AS DEFAULT ------------------

#GENERATING FILESYSTEM TABLE -> for partitions mounting to /mnt & redirecting output to /etc/fstab fo new SYSTEM
genfstab -U -p /mnt >> /mnt/etc/fstab

# SETTING UP THE NEW ARCH SYSTEM

#function to install GRUB bootloader
install_grub(){
      #check if the system is booted into UEFI mode 
      if mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null;then
          echo "UEFI mode detected. Installing GRUB to UEFI"
          umount /sys/firmware/efi/efivars
          sudo grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
          sudo grub-mkconfig -o /boot/grub/grub.cfg
      else
        echo "Legacy mode detected. installing GRUB for Legacy BIOS"
        sudo grub-install --target=i386-pc /dev/sda 
        sudo grub-mkconfig -o /boot/grub/grub.cfg
      fi
}
#-------------------------------> GRUB THEMING --------------------->


#function to automate switching the user


new_system(){
   echo "'Chrooting' into the new Arch Linux System ... "

   arch-chroot /mnt 
   #INSTALLING PACKAGES TO THE NEW SYSTEM

####-----------------------------> SOURCED FILE HERE ------------------->

   install_packages

   #CONFIGURINTH THE SYSTEM
   #localization
   echo "Dealing with localization ...."
   echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
   locale-gen
   echo "LANG=en_US.UTF-8" > /etc/locale.conf
   export LANG=en_US.UTF-8 
   #-----> CHOOSING MORE LOCALES BUT HAVE THIS AS DEFAULT ----------------<

   #timezone

   ###### ----------------> FILE TO BE SOURCED HERE --------------------------> 
 

   #user
####-----------------------------> SOURCED FILE HERE --------------------------------->

   #MODIFYING THE SUDOERS FILE
####-----------------------------> SOURCED FILE HERE --------------------------------->
   modify_sudoers

   #NETWORK CONFIGURATION ...
####-----------------------------> SOURCED FILE HERE --------------------------------->
   enable_dhcpcd

   #installing bootloader (GRUB):
   install_grub

   #enabling multilib support

####-----------------------------> SOURCED FILE HERE ------------------------------------>
   enable_multilib_support


   #CONFIGURING THE SYSTEM FOR THE NEW USER
   switch_user '$username' 'user_passwd'    
    #append any more desired packages as needed, after the username and password  
   local result=$?

   if [ $result -eq 0 ]; then
        echo "Switching to user was successful."
   else
        echo "Switching to user failed."
   fi

# ENVIRONMENT SETUP ------------------> SOURCED FILE -------------------------------------->
   


}





