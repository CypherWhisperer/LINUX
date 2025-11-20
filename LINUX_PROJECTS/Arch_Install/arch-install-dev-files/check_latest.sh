#!/bin/bash 

#latest_version=$(curl -s https://repo.anaconda.com/archive/ | grep -o 'Anaconda3-[0-9]\{4\}\.[0-9]\{2\}\}\.[0-9]\{2\}-Linux-x86_64.sh' | sort -V | tail -n 1)

#latest_version=$(curl -s https://repo.anaconda.com/archive/ | grep -o 'Anaconda3-[0-9]\{4\}\.[0-9]\{2\}\}\.[0-9]\{2\}-Linux-x86_64.sh' | sort -V | tail -n 1)
#echo $latest_version

#!/bin/bash

# Fetch the list of available versions
page_content=$(curl -s https://repo.anaconda.com/archive/)

# Debug: Print the fetched content to check the structure
# echo "$page_content" # Uncomment this line to see the page content

# Extract the latest version
latest_version=$(echo "$page_content" | grep -o 'Anaconda3-[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-Linux-x86_64.sh' | sort -V | tail -n 1)

# Check if latest_version is empty
if [ -z "$latest_version" ]; then
    echo "Error: Could not find the latest Anaconda installer version."
    exit 1
fi

# Construct the full URL
latest_url="https://repo.anaconda.com/archive/$latest_version"

# Print the URL of the latest Anaconda installer
echo "The latest Anaconda installer is: $latest_url"

#CHECKING THE AVAILABLE VERSIONS .. 

echo "Now checking the available versions from the site: "
#!/bin/bash

# Fetch the list of available versions
page_content=$(curl -s https://repo.anaconda.com/archive/)

# Extract and list all versions
available_versions=$(echo "$page_content" | grep -o 'Anaconda3-[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}-Linux-x86_64.sh')

# Check if any versions were found
if [ -z "$available_versions" ]; then
    echo "Error: Could not find any Anaconda installer versions."
    exit 1
fi

# Print all available versions
echo "Available Anaconda installer versions:"
echo "$available_versions"

# Extract the latest version
latest_version=$(echo "$available_versions" | sort -V | tail -n 1)

# Construct the full URL for the latest version
latest_url="https://repo.anaconda.com/archive/$latest_version"

# Print the URL of the latest Anaconda installer
echo "The latest Anaconda installer is: $latest_url"



