#!/bin/bash

   echo -n "Input hostname for new system: "
   read -r hostname
   echo -n "Input password for root: "
   read -r root_passwd
   echo -n "input name for the new user: "
   read -r username
   echo -n "input password for new user $username: "
   read user_passwd

   echo $hostname > /etc/hostname

   useradd -m -g users -G wheel,storage,power -s /bin/bash '$username'

   set_user_passwd '$username' '$user_passwd'
   set_user_passwd root '$root_passwd'

set_user_passwd(){
  local username="$1"
  local passwd="$2"

  #combining the password and the username in the format user:passwd
  echo "${username}":"${passwd}" | sudo chpasswd
  if [[$? -eq 0]];then
    echo "Password for user: '$username' set successfully ... "
  else
    echo "Failled to set password for user: '$username'.">&2
  fi
}

