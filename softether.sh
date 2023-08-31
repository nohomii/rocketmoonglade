#!/bin/bash

# Update and upgrade
apt update && apt upgrade -y

# Install prerequisites
apt-get -y install build-essential wget make curl gcc zlib1g-dev tzdata git libreadline-dev libncurses-dev libssl-dev

# Download SoftEther VPN Server
wget https://www.softether-download.com/files/softether/v4.42-9798-rtm-2023.06.30-tree/Linux/SoftEther_VPN_Server/64bit_-_Intel_x64_or_AMD64/softether-vpnserver-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz

# Extract downloaded file
tar xzf softether-vpnserver-v4.42-9798-rtm-2023.06.30-linux-x64-64bit.tar.gz

# Navigate to the vpnserver directory
cd vpnserver

# Compile the downloaded file
make

# Go back to the original directory
cd ..

# Move vpnserver directory to /usr/local
mv vpnserver /usr/local

# Navigate to the vpnserver directory
cd /usr/local/vpnserver/

# Set permissions
chmod 600 *
chmod 700 vpnserver vpncmd

# Start the server
./vpnserver start

# Enter management panel
./vpncmd

# Set password for the management panel
ServerPasswordSet

exit

# Create systemd service file
cat << EOF | sudo tee /lib/systemd/system/vpnserver.service
[Unit]
Description=SoftEther VPN Server
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/vpnserver/vpnserver start
ExecStop=/usr/local/vpnserver/vpnserver stop

[Install]
WantedBy=multi-user.target
EOF

# Enable IP forwarding
echo net.ipv4.ip_forward = 1 | sudo tee -a /etc/sysctl.conf

# Enable and start the service
systemctl enable vpnserver
systemctl start vpnserver
systemctl status vpnserver

# Configure firewall settings
ufw allow 443
ufw allow 500,4500/udp
ufw allow 1701
ufw allow 1194
ufw allow 5555

# Exit
exit 0
