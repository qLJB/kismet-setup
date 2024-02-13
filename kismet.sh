#!/bin/bash

# Get the current username
username=$(whoami)

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root or using sudo."
  exit 1
fi

# Download and install Kismet repository key if not already present
echo -e "\e[92mDownloading and installing Kismet repository key...\e[0m"
if ! gpg --list-keys "0x6D02CCDA4D8A45B4" > /dev/null 2>&1; then
    wget -O - https://www.kismetwireless.net/repos/kismet-release.gpg.key --quiet | gpg --dearmor | sudo tee /usr/share/keyrings/kismet-archive-keyring.gpg > /dev/null 2>&1
else
    echo -e "\e[93mKismet repository key is already installed.\e[0m"
fi

# Add Kismet repository to sources.list if not already present
echo -e "\e[92mAdding Kismet repository to sources.list...\e[0m"
if ! grep -q 'deb \[signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg\] https://www.kismetwireless.net/repos/apt/release/bookworm bookworm main' /etc/apt/sources.list.d/kismet.list; then
    echo 'deb [signed-by=/usr/share/keyrings/kismet-archive-keyring.gpg] https://www.kismetwireless.net/repos/apt/release/bookworm bookworm main' | sudo tee -a /etc/apt/sources.list.d/kismet.list > /dev/null 2>&1
else
    echo -e "\e[93mKismet repository is already present in sources.list.\e[0m"
fi



# Update package information (suppress output)
echo -e "\e[92mUpdating package information...\e[0m"
sudo apt update -y > /dev/null 2>&1

# Install Kismet
echo -e "\e[92mInstalling Kismet...\e[0m"
sudo apt install kismet -y > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "\e[92mKismet installed successfully.\e[0m"
else
    echo -e "\e[91mFailed to install Kismet.\e[0m"
    exit 1
fi

# Install Aircrack-ng
echo -e "\e[92mInstalling Aircrack-ng...\e[0m"
sudo apt install aircrack-ng -y > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "\e[92mAircrack-ng installed successfully.\e[0m"
else
    echo -e "\e[91mFailed to install Aircrack-ng.\e[0m"
    exit 1
fi

# Install gpsd and gpsd-clients
echo -e "\e[92mInstalling gpsd and gpsd-clients...\e[0m"
sudo apt install gpsd gpsd-clients -y > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo -e "\e[92mgpsd and gpsd-clients installed successfully.\e[0m"
else
    echo -e "\e[91mFailed to install gpsd and gpsd-clients.\e[0m"
    exit 1
fi

sudo gpsd -F /var/run/gpsd.sock /dev/ttyACM0

# Add user to the Kismet group if not already a member
echo -e "\e[92mAdding $username to kismet group...\e[0m"
if ! groups $username | grep -q '\bkismet\b'; then
    sudo usermod -aG kismet $username
else
    echo -e "\e[93m$username is already a member of the kismet group.\e[0m"
fi

# Enable Kismet service if not already enabled
echo -e "\e[92mEnabling Kismet service...\e[0m"
if ! sudo systemctl is-enabled kismet &>/dev/null; then
    sudo systemctl enable kismet
else
    echo -e "\e[93mKismet service is already enabled.\e[0m"
fi

# Checking if --override wardrive is already in the ExecStart line
if ! sudo grep -q 'ExecStart=.*--override wardrive' /lib/systemd/system/kismet.service; then
    # Adding --override wardrive to the ExecStart line
    echo -e "\e[92mAdding --override wardrive to Kismet service ExecStart line...\e[0m"
    sudo sed -i 's|^\(ExecStart=.*\)$|\1 --override wardrive|' /lib/systemd/system/kismet.service
else
    # Informing that --override wardrive is already present
    echo -e "\e[93m--override wardrive is already in Kismet service ExecStart line.\e[0m"
fi

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

