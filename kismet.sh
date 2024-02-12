#!/bin/bash

# Get the current username
username=$(whoami)

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or using sudo."
  exit 1
fi

# Download and install Kismet repository key
echo -e "\e[92mDownloading and installing Kismet repository key...\e[0m"
wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg >/dev/null

# Add Kismet repository to sources.list
echo -e "\e[92mAdding Kismet repository to sources.list...\e[0m"
echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bookworm bookworm main' | sudo tee /etc/apt/sources.list.d/kismet.list >/dev/null

# Update package information (suppress output)
echo -e "\e[92mUpdating package information...\e[0m"
sudo apt update -y > /dev/null 2>&1

# Install Kismet and Aircrack-ng
echo -e "\e[92mInstalling Kismet and Aircrack-ng this may take some time...\e[0m"
echo -e "\e[92mIt may look as if im frozen but im not :)\e[0m"
if sudo apt install kismet aircrack-ng -y > /dev/null 2>&1; then
  echo -e "\e[92mKismet and Aircrack-ng installed successfully.\e[0m"
else
  echo -e "\e[91mFailed to install Kismet and Aircrack-ng. Check for errors above.\e[0m"
  exit 1
fi

# Add user to the Kismet group
echo -e "\e[92mAdding $username to kismet group...\e[0m"
sudo usermod -aG kismet $username

# Enable Kismet service
echo -e "\e[92mEnabling Kismet service...\e[0m"
sudo systemctl enable kismet

# Modify the ExecStart line to include --override wardrive
echo -e "\e[92mAdding --override wardrive to Kismet service ExecStart line...\e[0m"
sudo sed -i 's|^\(ExecStart=.*\)$|\1 --override wardrive|' /lib/systemd/system/kismet.service

# Reload systemd manager to apply the changes
sudo systemctl daemon-reload

# Detect and put all available wireless interfaces into monitor mode using Aircrack-ng
echo -e "\e[92mDetecting and putting all available wireless interfaces into monitor mode using Aircrack-ng...\e[0m"

echo -e "\e[92mChecking and killing processes that could interfere..."
sudo airmon-ng check kill > /dev/null 2>&1

for interface in $(iw dev | grep Interface | awk '{print $2}'); do
  if sudo airmon-ng start "$interface" > /dev/null 2>&1; then
    echo -e "\e[92mMonitor mode set for $interface."

    # Checking if the source entry already exists in the config file
    if ! sudo grep -q "source=$interface" /etc/kismet/kismet.conf; then
      # Writing to Kismet's wireless config file if it doesn't exist
      echo -e "\e[92mAdding $interface as a startup source into config"
      echo "source=$interface" | sudo tee -a /etc/kismet/kismet.conf >/dev/null
    fi
  else
    echo -e "\e[91mFailed to set $interface into monitor mode.\e[0m"
    failed_interface=$(sudo airmon-ng | grep "$interface" | awk '{print $2}')
    echo "Failed interface details:"
    sudo airmon-ng | grep "$failed_interface"
  fi
done

sudo systemctl restart kismet

local_ip=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
echo -e "\e[92mKismet installation, configuration, and monitor mode setup completed.\e[0m"
echo -e "\e[92mThe Kismet web UI: $local_ip:2501."
echo -e "\e[92mSetup the user then reboot the machine for all changes to take effect."

