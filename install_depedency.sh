echo "Installing Nginx and Certbot (for SSL)"

sudo apt update
sudo apt install -y nginx
sudo apt install -y build-essential apt-transport-https lsb-release ca-certificates curl
sudo apt install -y certbot python3-certbot-nginx

sudo apt-add-repository --yes ppa:ondrej/php
sudo apt update

echo "Installing PHP...."
sudo apt install -y php8.0 php8.0-fpm php8.0-mysql
sudo apt install -y php8.0-soap php8.0-xml php8.0-curl php8.0-gd php8.0-intl php8.0-xmlrpc php8.0-zip php8.0-mbstring