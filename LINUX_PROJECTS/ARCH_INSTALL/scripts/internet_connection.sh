#!/bin/bash


connect_to_wifi(){
  local ssid=""
  local passwd=""
  local retry=0

  while true do
    if [[$retry -gt 0]];then
      echo "Previous attempt to connect failed! "
      echo "Input 'skip' to skip or"
    fi

    echo "Input the Network SSID (or 'skip' to skip): "
    read -r ssid
    if [["$ssid" == "skip"]];then
      echo "Skipping WIFI connection setup! "
      return 1 #return non-zero value, indicating skip
    fi

    echo "Input Passphrase to Network (or 'skip' to skip): "
    read -rs passwd
    if [["$passwd" == "skip"]]then
      echo "Skipping WIFI connection setup! "
      return 1
    fi

    if iwctl --passphrase "$passwd" station wlan0 connect "$ssid"; then
      echo "WIFI connection successful ..."
      return 0
    else
      echo "WIFI connection attempt failed! "
      retry = $((retry +1))

    fi
  done
}

check_connection(){
  if $(ping -c 1 google.com &> /dev/null) then
    echo "Ping: WIFI connection active ..."
  else
    echo "Ping: WIFI conection Inactive ... Attempting connection"
    if connect_to_wifi; then
      echo "WIFI setup completed ! ..."
    else
      echo "WIFI setup skipped or unsuccessful, Exiting...!"
      exit 1 #exit status for failure....
    fi
      
}
