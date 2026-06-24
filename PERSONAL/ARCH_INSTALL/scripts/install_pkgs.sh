#!/bin/bash

install_packages(){
       declare -a default_packages = ("nvim" "vim" "nano" "wget" "networkmanager" "grub" "efibootmgr" "dhcpcd" "curl" "btop" "neofetch")
       echo "The following packages will be installed: "
       printf '%s\n' "${default_packages[@]}"

       echo "Input additional packages (space-separated): "
       read -r -a additional_packages
       
       #merging the default and user defined packages
       local packages= ("${default_packages[@]}" "${additional_packages[@]}")
       local to_install=()

       for pkg in "${packages[@]}";do
         if pacman -Qs "^$pkg$" > /dev/null; then
           echo "$pkg" is already installed ...
        else
          #check if the package exists in pacman repositories
          if pacman -Si "$pkg$" &>/dev/null; then
            to_install += ("$pkg")
          else
            echo "package '$pkg' does not exist in the pacman database! "
          fi
        fi
      done

      if [[${#to_install[@]} -gt 0]];then
        echo "Installing packages: ${to_install[@]}"
        pacman -S "${to_install[@]}"

      else
        echo "the specified packages are allready installed or not found !"
      fi
}


#------------------------> dealing with aur packages ------------------------>