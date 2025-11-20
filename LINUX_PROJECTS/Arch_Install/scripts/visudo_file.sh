#!/bin/bash

#function to modify the sudoer file(/etc/sudoers)
modify_sudoers(){
       local sudoers_file="/etc/sudoers"
       local temp_file=$(mktemp)

       #check if sudoers file is readable
       if ! sudo visudo -c -q -f "$sudoers_file";then
         echo "Error: Sudoers file syntax check failed ! Aborting ..">&2
         exit 1
      fi
      sudo cp "$sudoers_file" "$sudoers_file.backup" #creating a backup

      #Changes: uncommenting and appending 
      if ! grep -q '^# %wheel ALL=(ALL:ALL) ALL' "$sudoers_file";then
        echo "No line beggining with '# %wheel ALL=(ALL:ALL) ALL' in the sudoers file">&2
        exit 1
      fi

      sed -e 's/^# \(%wheel ALL=(ALL:ALL) ALL\)$/\1/' "$sudoers_file" > "$temp_file"
      echo 'Defaults rootpw' >> "$temp_file"

      #validating the syntax for modified file
      if ! sudo visudo -c -q -f "$temp_file";then
          echo "Error: Modified sudoers file syntax check failed ! Restoring backup"
          sudo cp "$sudoers_file.backup" "sudoers_file"
          exit 1
      fi

      #repacing suders file with the modified version
      sudo cp "$temp_file" "$sudoers_file"
      echo "suders file modified successfully ..."

      #clean tem file
      rm "$temp_file"

}