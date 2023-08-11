#!/bin/bash

# Download and make executable the setup_script.sh and uninstall_script.sh
curl -sLO https://raw.githubusercontent.com/nohomii/rocketmoonglade/main/setup_script.sh
curl -sLO https://raw.githubusercontent.com/nohomii/rocketmoonglade/main/uninstall_script.sh
curl -sLO https://raw.githubusercontent.com/nohomii/rocketmoonglade/main/nohomi.sh

chmod +x setup_script.sh uninstall_script.sh nohomi.sh

# Add alias to .bashrc
sudo echo "alias nohomi='./nohomi.sh'" >> ~/.bashrc

# Source .bashrc to apply the changes
source ~/.bashrc

echo "Welcome to the Nohomi Script!"
echo "Please choose an option:"
echo "1. Install Nohomi Sing-box"
echo "2. Install Warp"
echo "3. Uninstall CMD Files"
echo "4. Uninstall Sing-box"
echo "5. Realityezpz"
echo "6. 3xUI Sanaei"
echo "7. X-UI Alireza"
echo "8. Marzban"
echo "9. Hiddify"
echo "10. Exit"

read choice

case $choice in
    1)
        ./setup_script.sh
        ;;
    2)
        bash <(wget -qO- https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh 2> /dev/null)
        ;;
    3)
        rm -rf /var/www/html/config
        echo "CMD files removed."
        ;;
    4)
        ./uninstall_script.sh
        ;;
   5)
    while true; do
        echo "Select an option for Realityezpz:"
        echo "1. Install Realityezpz"
        echo "2. Uninstall Realityezpz"
        echo "3. Return to main menu"
        read reality_choice
        case "$reality_choice" in
            1)
                bash <(curl -sL https://bit.ly/realityez) -d discordapp.com
                ;;
            2)
                bash <(curl -sL https://bit.ly/realityez) -u
                ;;
            3)
                break
                ;;
            *)
                echo "Invalid choice"
                ;;
        esac
    done
    ;;
    6)
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        ;;
    7)
        bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
        ;;
    8)
        sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install
        ;;
    9)
        sudo bash -c "$(curl -Lfo- https://raw.githubusercontent.com/hiddify/hiddify-config/main/common/download_install.sh)"
        ;;
    10)
        echo "Exiting."
        exit 0
        ;;
    *)
        echo "Invalid choice. Please select a valid option."
        ;;
esac
