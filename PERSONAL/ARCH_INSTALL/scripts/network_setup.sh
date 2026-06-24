#!/bin/bash
#network configuration functions
get_all_interfaces(){
     interfaces=($(ip -o link show | awk -F ': ' '{print $2}'))

      if [${#interfaces[@]} -eq 0];then
         echo "No Network Interface found !"
         exit 1
      fi
      for i in "${!interfaces[@]}";do #printing the interfaces
          echo "interface $((i + 1)): ${interfaces[$i]}"
      done

      #returnng the array of interfaces
      echo "${interfaces[@]}"

}
#function to enable dhcpcd at the interfaces...
enable_dhcpcd(){
  network_interfaces=($(get_all_interfaces))
  #function to check the integrity of each of the found interfaces
  check_interface_exists(){
       local interface=$1
       ip link show "$interface" >/dev/null 2>&1 #check if interface exists in system
       return $? #returns the exit status of the opration 
  }

  for interface in "${network_interfaces[@]}";do
      if check_interface_exists "$interface";then
          echo "Enabling dhcpcd@$interface"
          sudo systemctl enable --now dhcpcd@"$interface"
      else
        echo "Invalid interface: $interface"
      fi
  echo "Enabling NetworkManager service ... "
  sudo systemctl enable NetworkManager.service
  done
}