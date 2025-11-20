#!/bin/bash

#function to set up the directories for the user
#----------------------------> CONSIDER A FOR LOOP TO ITERATE OVER EACH USER
directory_setup(){
  decalare -a directories=(
        "$HOME/Documents/scripts"
        "$HOME/Downloads"
        "$HOME/Music"
        "$HOME/Movies"
        "$HOME/Pictures"
        "$HOME/Apps")
#now to create the directories if they don't already exist
  create_directories(){
    for dir in "${directories[@]}";do
         if [! -d "$dir"];then
           mkdir -p "$dir"
           echo "Created directory: $dir"
         else
           echo "Directory '$dir' Already Exists...."
         fi
    done
  }

  echo "Setting up the directory structure .... "
  create_directories
  echo "Directory setup complete ... "
}