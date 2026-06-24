#!/bin/bash

# Function to set user password
set_password() {
    local user="$1"
    local password="$2"

    # Check if both username and password are provided
    if [ -z "$user" ] || [ -z "$password" ]; then
        echo "Usage: $0 <username> <password>"
        exit 1
    fi

    echo "$password" | sudo passwd --stdin "$user"
    if [ $? -eq 0 ]; then
        echo "Password for user $user has been successfully set."
    else
        echo "Failed to set password for user $user."
        exit 2
    fi
}

# Example usage: Set password for user 'testuser'
set_password "testuser" "new_password"
#!/bin/bash

# Function to set password for a user
set_user_password() {
    local username="$1"
    local password="$2"

    # Combine username and password in the format 'username:password'
    echo "${username}:${password}" | sudo chpasswd
}

# Example usage: Set password for user 'exampleuser'
set_user_password "exampleuser" "newpassword"
#!/bin/bash

# Function to set password for a user
set_user_password() {
    local username="$1"
    local password="$2"

    # Combine username and password in the format 'username:password'
    echo "${username}:${password}" | sudo chpasswd

    # Check if the password change was successful
    if [[ $? -eq 0 ]]; then
        echo "Password for user '$username' was successfully changed."
    else
        echo "Failed to change password for user '$username'." >&2
    fi
}

# Example usage: Set password for user 'exampleuser'
set_user_password "exampleuser" "newpassword"

