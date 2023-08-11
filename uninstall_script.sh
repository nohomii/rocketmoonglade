#!/bin/bash

# Stop and disable services
systemctl stop sing-box
systemctl disable sing-box
systemctl stop haproxy
systemctl disable haproxy
systemctl stop nginx
systemctl disable nginx

# Remove systemd service files
rm /etc/systemd/system/sing-box.service
rm /etc/systemd/system/haproxy.service
rm /etc/systemd/system/nginx.service

# Remove Sing-box binary and config
rm /root/sing-box
rm /root/sing-box_config.json

# Remove Sing-box public and private keys
rm /root/private.key
rm /root/public.key

# Remove Sing-box-generated files
rm /root/cert.crt
rm /root/link1_qr.png
rm /root/link2_qr.png

# Remove acme.sh and its data
/root/.acme.sh/acme.sh --uninstall
rm -rf /root/.acme.sh

# Remove haproxy and nginx configs
rm /etc/haproxy/haproxy.cfg
rm /etc/nginx/nginx.conf

# Remove HTML directory
rm -rf /var/www/html

# Uninstall qrencode
apt-get -y remove qrencode

echo "Uninstallation completed."

