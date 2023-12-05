#!/bin/bash

# Fancy title and description
echo -e "\e[1;33m
    _   _           ___      _______   _____ 
   | \ | |         | \ \    / /  __ \ / ____|
   |  \| | _____  _| |\ \  / /| |__) | (___  
   | . \` |/ _ \ \/ / __\ \/ / |  ___/ \___ \ 
   | |\  |  __/>  <| |_ \  /  | |     ____) |
   |_| \_|\___/_/\_\\__| \/   |_|    |_____/ 
                                             
\e[0m"
echo -e "\e[1;32mNEXTVPS: A tool for deploying Next.js, React.js and other Node.js based web applications on a Linux based VPS server using GitHub.\e[0m"
echo -e "\e[1;34mAuthors: The dev team of netbay.in\e[0m"

# Function to display the menu
function menu {
    echo -e "\e[1;36m1. Deploy a website using GitHub"
    echo "2. Show currently deployed websites"
    echo "3. Restart NGINX"
    echo "4. Remove a website"
    echo "5. Redeploy SSL certificate"
    echo "6. Exit\e[0m"
}

# Update and upgrade the server
echo -e "\e[1;35mSetting up the environment...\e[0m"
sudo yum update

# Check if dependencies are installed and install if not
if ! command -v nginx &> /dev/null
then
    echo -e "\e[1;31mNGINX could not be found, installing...\e[0m"
    sudo yum install nginx -y
fi

if ! command -v certbot &> /dev/null
then
    echo -e "\e[1;31mCertbot could not be found, installing...\e[0m"
    sudo yum install certbot python3-certbot-nginx -y
fi

if ! command -v npm &> /dev/null
then
    echo -e "\e[1;31mNPM could not be found, installing...\e[0m"
    sudo yum install npm -y
fi

if ! command -v pm2 &> /dev/null
then
    echo -e "\e[1;31mpm2 could not be found, installing...\e[0m"
    sudo npm install -g pm2 -y
fi

if ! command -v curl &> /dev/null
then
    echo -e "\e[1;31mCurl could not be found, installing...\e[0m"
    sudo yum install curl -y
fi

if ! command -v nvm &> /dev/null
then
    echo -e "\e[1;31mNVM could not be found, installing...\e[0m"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
    echo "nvm install --lts" > install_nvm.sh
    chmod +x install_nvm.sh
    ./install_nvm.sh
    rm install_nvm.sh
fi

if ! command -v git &> /dev/null
then
    echo -e "\e[1;31mGit could not be found, installing...\e[0m"
    sudo yum install git -y
fi

if ! command -v python3 &> /dev/null
then
    echo -e "\e[1;31mPython3 could not be found, installing...\e[0m"
    sudo yum install python3 -y
fi

echo -e "\e[1;32mEnvironment setup is done.\e[0m"

# Menu loop
while true; do
    menu
    read -p "Choose an option: " OPTION
    case $OPTION in
        1)  # Deploy a website using GitHub
            while true; do
                read -p "Enter the HTTP git link of your public repository: " REPO_LINK
                if [[ $REPO_LINK != https://github.com/* ]]
                then
                    echo -e "\e[1;31mInvalid repository link. Please make sure it's a public GitHub repository.\e[0m"
                    echo "1. Quit"
                    echo "2. Re-enter another link"
                    read -p "Choose an option: " CHOICE
                    if [[ $CHOICE == "1" ]]
                    then
                        break 2
                    elif [[ $CHOICE == "2" ]]
                    then
                        continue
                    else
                        echo -e "\e[1;31mInvalid choice. Please enter '1' to quit or '2' to re-enter another link.\e[0m"
                    fi
                else
                    break
                fi
            done
            read -p "Enter your app name: " APP_NAME
            read -p "Enter your domain name: " DOMAIN_NAME
            cd /var/www
            git clone $REPO_LINK $APP_NAME
            if [ $? -ne 0 ]
            then
                echo -e "\e[1;31mFailed to clone the repository. Please check the repository link and try again.\e[0m"
                continue
            fi
            cd $APP_NAME
            npm install
            if [ $? -ne 0 ]
            then
                echo -e "\e[1;31mFailed to install dependencies. Please check your package.json file.\e[0m"
                rm -rf /var/www/$APP_NAME
                exit 1
            fi
            npm run build
            if [ $? -ne 0 ]
            then
                echo -e "\e[1;31mFailed to build the application. Please check your scripts in package.json file.\e[0m"
                rm -rf /var/www/$APP_NAME
                exit 1
            fi
            cd /etc/nginx/sites-available
            echo "server {
                listen 80;
                server_name $DOMAIN_NAME;
                location / {
                    proxy_pass http://localhost:$((3000 + $(ls | wc -l)));
                    proxy_http_version 1.1;
                    proxy_set_header Upgrade \$http_upgrade;
                    proxy_set_header Connection 'upgrade';
                    proxy_set_header Host \$host;
                    proxy_cache_bypass \$http_upgrade;
                }
            }" > $APP_NAME
            ln -s /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
            systemctl restart nginx
            cd /var/www/$APP_NAME
            pm2 start npm --name $APP_NAME -- start
            sudo certbot --nginx -d $DOMAIN_NAME
            if [ -f "next.config.js" ]
            then
                sed -i "s/port: 3000/port: $((3000 + $(ls /etc/nginx/sites-available | wc -l)))/" next.config.js
                echo -e "\e[1;32mNext.js website deployed successfully.\e[0m"
            else
                echo -e "\e[1;32mWebsite deployed successfully. If your website is using a web pack other than Next.js, you may need to manually edit the 'start' script in the package.json file located at /var/www/$APP_NAME/package.json to use the correct port.\e[0m"
            fi
            ;;
        2)  # Show currently deployed websites
            echo "Currently deployed websites:"
            ls /etc/nginx/sites-available | cat -n
            read -p "Enter the number of the website you want to see the details of: " WEBSITE_NUMBER
            WEBSITE_NAME=$(ls /etc/nginx/sites-available | sed -n "$WEBSITE_NUMBER"p)
            echo -e "\e[1;33m
            ┌──────────────────────────────────────────────────────────────┐"
            echo -e "│\e[0m\e[1;36mApp Name: $WEBSITE_NAME\e[0m\e[1;33m                                               │"
            echo -e "│\e[0m\e[1;36mDomain Name: $(grep -oP 'server_name \K.*?(?=;)' /etc/nginx/sites-available/$WEBSITE_NAME)\e[0m\e[1;33m                          │"
            echo -e "│\e[0m\e[1;36mPort: $(grep -oP 'proxy_pass http://localhost:\K.*?(?=;)' /etc/nginx/sites-available/$WEBSITE_NAME)\e[0m\e[1;33m                        │"
            echo -e "│\e[0m\e[1;36mSSL Status: $(if sudo nginx -t 2>&1 | grep -q "/etc/letsencrypt/live/$WEBSITE_NAME/fullchain.pem"; then echo "Enabled"; else echo "Disabled"; fi)\e[0m\e[1;33m │"
            echo -e "│\e[0m\e[1;36mSSL Expiry Date: $(if sudo nginx -t 2>&1 | grep -q "/etc/letsencrypt/live/$WEBSITE_NAME/fullchain.pem"; then echo $(date -d "$(openssl x509 -enddate -noout -in /etc/letsencrypt/live/$WEBSITE_NAME/fullchain.pem | cut -d= -f 2)" --iso-8601); else echo "N/A"; fi)\e[0m\e[1;33m │
            └──────────────────────────────────────────────────────────────┘\e[0m"
            echo -e "\e[1;36mNginx Configuration:\e[0m"
            cat /etc/nginx/sites-available/$WEBSITE_NAME
            echo -e "\e[1;36mSSL Certificate Status:\e[0m"
            if sudo nginx -t 2>&1 | grep -q "/etc/letsencrypt/live/$WEBSITE_NAME/fullchain.pem"
            then
                echo "Certificate Path: /etc/letsencrypt/live/$WEBSITE_NAME/fullchain.pem"
                echo "Private Key Path: /etc/letsencrypt/live/$WEBSITE_NAME/privkey.pem"
                openssl x509 -in /etc/letsencrypt/live/$WEBSITE_NAME/fullchain.pem -text -noout
            else
                echo "No SSL certificate found for this website."
            fi
            ;;
        3)  # Restart NGINX
            systemctl restart nginx
            ;;
        4)  # Remove a website
            echo "Currently deployed websites:"
            ls /etc/nginx/sites-available | cat -n
            read -p "Enter the number of the website you want to remove: " WEBSITE_NUMBER
            WEBSITE_NAME=$(ls /etc/nginx/sites-available | sed -n "$WEBSITE_NUMBER"p)
            sudo rm -rf /var/www/$WEBSITE_NAME
            sudo rm /etc/nginx/sites-available/$WEBSITE_NAME
            sudo rm /etc/nginx/sites-enabled/$WEBSITE_NAME
            sudo rm -rf /etc/letsencrypt/live/$WEBSITE_NAME
            sudo rm -rf /etc/letsencrypt/archive/$WEBSITE_NAME
            sudo rm /etc/letsencrypt/renewal/$WEBSITE_NAME.conf
            systemctl restart nginx
            echo -e "\e[1;32mWebsite removed successfully.\e[0m"
            ;;
        5)  # Redeploy SSL certificate
            echo "Currently deployed websites:"
            ls /etc/nginx/sites-available | cat -n
            read -p "Enter the number of the website you want to redeploy SSL certificate for: " WEBSITE_NUMBER
            WEBSITE_NAME=$(ls /etc/nginx/sites-available | sed -n "$WEBSITE_NUMBER"p)
            sudo certbot --nginx -d $(grep -oP 'server_name \K.*?(?=;)' /etc/nginx/sites-available/$WEBSITE_NAME)
            echo -e "\e[1;32mSSL certificate redeployed successfully.\e[0m"
            ;;
        6)  # Exit
            if ! [ -f ~/.ssh/id_rsa.pub ]
            then
                echo -e "\e[1;33m
                ┌──────────────────────────────────────────────────────────────┐
                │                                                              │
                │   Tip: It seems you haven't set up SSH keys on this server.   │
                │   It's a good practice to set up SSH keys for authentication. │
                │   You can generate a new SSH key pair using the command:     │
                │                                                              │
                │   ssh-keygen -t rsa -b 4096 -C \"your_email@example.com\"    │
                │                                                              │
                │   Then you can add the public key to your GitHub account.    │
                │                                                              │
                └──────────────────────────────────────────────────────────────┘
                \e[0m"
            fi
            break
            ;;
        *)  echo "Invalid option"
            ;;
    esac
done
