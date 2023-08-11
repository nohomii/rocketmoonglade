#!/bin/bash

# Step 1: Update and upgrade
apt update && apt upgrade -y

# Step 2: Install required packages
apt install -y curl socat net-tools haproxy nginx qrencode

# Step 3: Download and install Sing-box binary
curl -Lo /root/sb https://github.com/SagerNet/sing-box/releases/download/v1.3.6/sing-box-1.3.6-linux-amd64.tar.gz
tar -xzf /root/sb
cp -f /root/sing-box-*/sing-box /root
rm -r /root/sb /root/sing-box-*
chown root:root /root/sing-box
chmod +x /root/sing-box

# Step 4: Download Sing-box service file
curl -Lo /etc/systemd/system/sing-box.service https://raw.githubusercontent.com/chika0801/sing-box-examples/main/sing-box.service

# Step 5: Modify Sing-box service file
sed -i 's|ExecStart=/usr/local/bin/sing-box|ExecStart=/root/sing-box|' /etc/systemd/system/sing-box.service

# Step 6: Reload systemd
systemctl daemon-reload

# Step 7: Create sing-box_config.json
touch /root/sing-box_config.json

# Step 8: Modify sing-box_config.json
cat << EOF > /root/sing-box_config.json
{
    "log": {
        "level": "info",
        "timestamp": true
    },
    "inbounds": [
        {
            "type": "vless",
            "tag": "vless-in",
            "listen": "127.0.0.1",
            "listen_port": 8443,
            "users": [
                {
                    "uuid": "[Variable1]",
                    "flow": ""
                }
            ],
            "tls": {
                "enabled": true,
                "server_name": "[Variable2]",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "[Variable2]",
                        "server_port": 443
                    },
                    "private_key": "[Variable3]",
                    "short_id": [
                        "[Variable5]"
                    ]
                }
            }
        },
		{
            "type": "vless",
            "tag": "vlesss-in",
            "listen": "127.0.0.1",
            "listen_port": 8485,
            "users": [
                {
                    "uuid": "[Variable1]",
                    "flow": ""
                }
            ],
			"transport": 
			{
				"type": "http"
			},
            "tls": {
                "enabled": true,
                "server_name": "[Variable4]",
                "reality": {
                    "enabled": true,
                    "handshake": {
                        "server": "[Variable4]",
                        "server_port": 443
                    },
                    "private_key": "[Variable3]",
                    "short_id": [
                        "[Variable6]"
                    ]
                }
            }
        }
	
    ],
    "outbounds": [
         {
            "type": "direct",
            "tag": "direct"
        }
    ]
}
EOF

# Step 9: Ask user for UUID or generate a random one
read -p "Enter UUID [or press Enter for random]: " uuid
uuid=${uuid:-$(/root/sing-box generate uuid)}

# Step 10: Ask user for server names
read -p "Enter first server name [or press Enter for default]: " server1
server1=${server1:-"cdn.discordapp.com"}

read -p "Enter second server name [or press Enter for default]: " server2
server2=${server2:-"discordapp.com"}

# Step 11: Generate Reality keypair and capture output
keypair_output=$(sudo /root/sing-box generate reality-keypair)

# Extract PrivateKey and PublicKey values
private_key=$(echo "$keypair_output" | awk '/PrivateKey:/{print $2}')
public_key=$(echo "$keypair_output" | awk '/PublicKey:/{print $2}')

short_id1=$(/root/sing-box generate rand --hex 8)
short_id2=$(/root/sing-box generate rand --hex 8)

# Step 12: Replace variables in the config file
sed -i "s|\[Variable1\]|$uuid|g" /root/sing-box_config.json
sed -i "s|\[Variable2\]|$server1|g" /root/sing-box_config.json
sed -i "s|\[Variable3\]|$private_key|g" /root/sing-box_config.json
sed -i "s|\[Variable4\]|$server2|g" /root/sing-box_config.json
sed -i "s|\[Variable5\]|$short_id1|g" /root/sing-box_config.json
sed -i "s|\[Variable6\]|$short_id2|g" /root/sing-box_config.json

echo "Configuration completed."

#!/bin/bash

# ... Previous steps ...

# Temp disable nginx
sudo systemctl stop nginx

# Step 12: Download and install Acme script
curl https://get.acme.sh | sh

# Step 13: Set default provider to Let’s Encrypt
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt

# Step 14: Register user account with email
read -p "Enter your email address for Let's Encrypt registration: " email
~/.acme.sh/acme.sh --register-account -m "$email"

# Step 15: Issue SSL certificate
read -p "Enter your domain for SSL certificate issuance: " domain
~/.acme.sh/acme.sh --issue -d "$domain" --standalone

# Step 16: Install certificate and key files
~/.acme.sh/acme.sh --installcert -d "$domain" --key-file /root/private.key --fullchain-file /root/cert.crt

# Step 17: Configure haproxy
cat << EOF > /etc/haproxy/haproxy.cfg
global
    log /dev/log local0 info
    log /dev/log local1 info
    chroot /var/lib/haproxy
    user haproxy
    group haproxy
    daemon

    # performance
    maxconn 5000

defaults
    log global
    mode tcp
    option tcplog
    option dontlognull
    timeout connect 30s
    timeout client 60s
    timeout server 60s

frontend front_tcp
    bind *:443

    tcp-request inspect-delay 2s
    tcp-request content accept if { req_ssl_hello_type 1 } # your server's sni goes here

    acl discord_sni req_ssl_sni -i $server1
    acl cdn_sni req_ssl_sni -i $server2

    use_backend reality if discord_sni
    use_backend cdn_reality if cdn_sni
    default_backend tcp_ws

backend reality
    mode tcp
    server reality 127.0.0.1:8443

backend tcp_ws
    mode tcp
    server tcp_ws 127.0.0.1:8080

backend cdn_reality
    mode tcp
    server cdn_reality 127.0.0.1:8485
EOF

echo "Haproxy configuration completed."

#!/bin/bash

# ... Previous steps ...

# Step 18: Check haproxy configuration
if ! sudo haproxy -c -f /etc/haproxy/haproxy.cfg; then
    echo "Haproxy configuration is not valid. Please edit the configuration file manually."
    exit 1
fi

# Step 19: Configure nginx
read -p "Enter the domain chosen for SSL certificate: " nginx_domain
cat << EOF > /etc/nginx/nginx.conf
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;

    # Add your custom configuration below this line:
    server {
        listen 127.0.0.1:8080 ssl http2;
        listen [::1]:8080 ssl http2;
        server_name $nginx_domain;

        ssl_certificate /root/cert.crt;
        ssl_certificate_key /root/private.key;
        ssl_protocols TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;

        location / {
            # Your website root directory
            root /var/www/html;
            index index.html;
        }
    }
}
EOF

echo "Nginx configuration completed."

#!/bin/bash

# ... Previous steps ...

# Step 20: Check nginx configuration
if ! sudo nginx -t; then
    echo "Nginx configuration is not valid. Please check the configuration file manually."
    exit 1
fi

# Step 21: Enable services
sleep 0.2
systemctl daemon-reload
systemctl restart haproxy nginx sing-box

# Step 22: Generate links
server_ipv4=$(curl -s http://checkip.amazonaws.com)

link1="vless://$uuid@$server_ipv4:443/?type=tcp&encryption=none&sni=$server1&alpn=h2&fp=chrome&security=reality&pbk=$public_key&sid=$short_id1#TCP"
link2="vless://$uuid@$server_ipv4:443/?type=http&encryption=none&sni=$server2&fp=chrome&security=reality&pbk=$public_key&sid=$short_id2#HTTP"

# Generate and display QR codes
qrencode -t ANSIUTF8 -o - "$link1"
echo "Link of TCP config: $link1"

qrencode -t ANSIUTF8 -o - "$link2"
echo "Link of HTTP config: $link2"

# Prompt user for proceeding to step 23
read -p "Do you want to proceed and generate client side configuration files? (y/n): " proceed

if [[ $proceed == "y" ]]; then
# Step 23: Generate client side configuration files

# TCP.json
tcp_config='{
  "dns": {
    "rules": [],
    "servers": [
      {
        "address": "tls://1.1.1.1",
        "tag": "dns-remote",
        "detour": "proxy",
        "strategy": "ipv4_only"
      }
    ]
  },
  "inbounds": [
    {
      "type": "tun",
      "interface_name": "ipv4-tun",
      "inet4_address": "172.19.0.1/28",
      "mtu": 1500,
      "stack": "gvisor",
      "endpoint_independent_nat": true,
      "auto_route": true,
      "strict_route": true,
      "sniff": true
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "'$server_ipv4'",
      "server_port": 443,
      "uuid": "'$uuid'",
      "flow": "",
      "tls": {
        "alpn": ["h2"],
        "enabled": true,
        "server_name": "'$server1'",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "'$public_key'",
          "short_id": "'$short_id1'"
        }
      },
      "packet_encoding": "xudp"
    },
    {
      "tag": "dns-out",
      "type": "dns"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "final": "proxy",
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      }
    ]
  }
}'

# HTTP.json
http_config='{
  "dns": {
    "rules": [],
    "servers": [
      {
        "address": "tls://1.1.1.1",
        "tag": "dns-remote",
        "detour": "proxy",
        "strategy": "ipv4_only"
      }
    ]
  },
  "inbounds": [
    {
      "type": "tun",
      "interface_name": "ipv4-tun",
      "inet4_address": "172.19.0.1/28",
      "mtu": 1500,
      "stack": "gvisor",
      "endpoint_independent_nat": true,
      "auto_route": true,
      "strict_route": true,
      "sniff": true
    }
  ],
  "outbounds": [
    {
      "type": "vless",
      "tag": "proxy",
      "server": "'$server_ipv4'",
      "server_port": 443,
      "uuid": "'$uuid'",
      "flow": "",
      "tls": {
        "enabled": true,
        "server_name": "'$server2'",
        "utls": {
          "enabled": true,
          "fingerprint": "chrome"
        },
        "reality": {
          "enabled": true,
          "public_key": "'$public_key'",
          "short_id": "'$short_id2'"
        }
      },
      "packet_encoding": "xudp",
      "transport": {
        "type": "http"
      }
    },
    {
      "tag": "dns-out",
      "type": "dns"
    }
  ],
  "route": {
    "auto_detect_interface": true,
    "final": "proxy",
    "rules": [
      {
        "protocol": "dns",
        "outbound": "dns-out"
      }
    ]
  }
}'

# Save configurations to files
mkdir -p /var/www/html/config
echo "$tcp_config" > /var/www/html/config/TCP.json
echo "$http_config" > /var/www/html/config/HTTP.json

# Display download links
echo "Link of TCP config: https://$nginx_domain/config/TCP.json"
echo "Link of HTTP config: https://$nginx_domain/config/HTTP.json"

else

    echo "alias nohomi='./nohomi.sh'" >> ~/.bashrc
    source ~/.bashrc
    echo "Script completed.You can now run 'nohomi' in the terminal to launch the menu script"
fi

echo "alias nohomi='./nohomi.sh'" >> ~/.bashrc
source ~/.bashrc
echo "Script completed.You can now run 'nohomi' in the terminal to launch the menu script"

