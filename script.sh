#!/bin/bash
#!/bin/sh

if [ "$(id -u)" != "0" ]; then
	echo "Please run the script with sudo (sudo sh install_wordpress.sh)"
	exit
fi

script_dir=$(pwd)
db_host='localhost'

check_mysql_sudo_works() {
	sudo mysql -e "select 1;"
}

exit_if_error() {
	if [ "$1" = "1" ]; then
		echo $2
	fi
}

ask_db_credentials() {
	while true; do
		echo Please enter new db name without any special characters and whitespace.
		read new_db_name
		str=$new_db_name
		if [ -z "$str" ]; then
			echo "ERROR: DB name should not be empty."
			continue
		fi

		case $str in
		*[!a-zA-Z0-9]*)
			echo "ERROR: DB name should not contain a special characters."
			continue
			;;
		esac

		break
	done

	while true; do
		echo Please enter new db user name without any special characters and whitespace.
		read new_db_username
		str=$new_db_username	

		if [ -z "$str" ]; then
			echo "ERROR: DB user should not be empty."
			continue
		fi

		case $str in
		*[!a-zA-Z0-9]*)
			echo "ERROR: DB user should not contain a special characters."
			continue
			;;
		esac

		break
	done

	while true; do
		echo "Please enter new db password without single quote (')"
		read new_db_password
		str=$new_db_password	

		if [ -z "$str" ]; then
			echo "ERROR: DB password should not be empty."
			continue
		fi

		case $str in
		*[\']*)
			echo "ERROR: Password should not contain single quote (')"
			continue
			;;
		esac

		break
	done
}

create_user() {
	echo "creating New user.."
	sudo mysql -e "CREATE DATABASE if not exists "$new_db_name" DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
	exit_if_error $? "Error creating database. Check you entered proper db name without special characters and re-run the script"
	sudo mysql -e "CREATE USER '$new_db_username'@'localhost' IDENTIFIED BY '$new_db_password';"
	exit_if_error $? "Error creating user. Check you entered proper db username without any special characters and re-run the script"
	sudo mysql -e "GRANT ALL PRIVILEGES ON * . * TO '$new_db_username'@'localhost';"
	exit_if_error $? "Something went wrong. Check you entered db username or dbname without any special characters"
	sudo mysql -e "FLUSH PRIVILEGES;"
}

create_user_using_root() {
	mysql -u$1 -p$2 -e "CREATE DATABASE if not exists "$new_db_name" DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
	exit_if_error $? "Error creating database. Check you entered proper db name without special characters or right root username or right root password and re-run the script"
	mysql -u$1 -p$2 -e "CREATE USER '$new_db_username'@'localhost' IDENTIFIED WITH mysql_native_password BY '$new_db_password';"
	exit_if_error $? "Error creating user. Check you entered proper db name without special characters or right root username or right root password and re-run the script"
	mysql -u$1 -p$2 -e "GRANT ALL PRIVILEGES ON * . * TO '$new_db_username'@'localhost';"
	exit_if_error $? "Error granting privileges. Please check root user as right permissions and re-run the script"
	mysql -u$1 -p$2 -e "FLUSH PRIVILEGES"
}

. ./install_depedency.sh

echo "Setting up database"


check_mysql_sudo_works
is_mysql_sudo_works=$?

if [ "$is_mysql_sudo_works" = "0" ]; then
	while true; do
		ask_db_credentials
		create_user
		res=$?
		if [ "$res" = "0" ]; then
			break;
		fi
		;;
		echo "Please re-enter and try again."
	done
else
	while true; do
	read -p "Seems like you have protected database with password. Do you know root username and password? (y/n) " yn
	case $yn in
	y)
		while true; do
			echo Please enter root user name
			read root_user
			echo Please enter root password
			read root_password
			sudo mysql -u$root_user -p$root_password -e "select 1;"
			if [ "$res" = "0" ]; then
				break;
			fi
			echo "Unable to connect to MySQL DB. Please enter correct MySQL root username and password."
		done

		while true; do
			ask_db_credentials
			create_user_using_root $root_user $root_password
			res=$?
			if [ "$res" = "0" ]; then
				break;
			fi
			echo "Please re-enter and try again."
		done
		;;

	n)
		echo "Sorry we cannot proceed further, please reset your mysql root password by following this link https://devanswers.co/how-to-reset-mysql-root-password-ubuntu/#4-test-new-root-password and re-run the script! "
		exit
		;;

	*)
		echo Invalid response. Please enter y or n
		;;
	esac
	done

fi

echo "Database setup successfull!"


while true; do
	# Ask the user for site name
	echo "Please enter the domain, without any special characters"
	read domain

	case $domain in
	*['!&()'@#$%^*?,:_+]*)
		echo "ERROR: Domain name should not contain special characters."
		continue
		;;
	esac
	break
done



domain_ip=$(dig +short $domain)
local_ip=$(curl checkip.amazonaws.com)

echo "Your domain ip is "$domain_ip
echo "Your server ip is "$local_ip

while true; do
	case $domain_ip in
	$local_ip)
		echo -n "Great domain IP matched with server IP!"
		break
		;;
	*)
		read -p "Seems like domain ip doesn't match with server ip. Do you want to continue anyway? (y/n) " yn
		case $yn in
		y) 
			echo ok, we will proceed 
			break
		;; 
		n)
			echo exiting...
			exit
			;;
		*)
			echo Invalid response. Please enter y or n
			;;
		esac
		;;
	esac
done

sudo sed -e "s/DOMAIN_NAME/${domain}/" templates/wordpress.conf >/etc/nginx/sites-available/$domain

sudo ln -s /etc/nginx/sites-available/$domain /etc/nginx/sites-enabled/
## sudo unlink /etc/nginx/sites-enabled/default
echo "nginx test"
sudo nginx -t

sudo systemctl reload nginx

echo "Installing wordpress.."
#Install required packages for wordpress

sudo systemctl restart php8.0-fpm
cd /tmp
curl -LO https://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz --transform "s/wordpress/${domain}/"
cp /tmp/${domain}/wp-config-sample.php /tmp/${domain}/wp-config.php
sudo cp -a /tmp/${domain}/. /var/www/${domain}/
sudo chown -R www-data:www-data /var/www/${domain}

cd ~
cd $script_dir

echo "Configuring Nginx..."

curl -s https://api.wordpress.org/secret-key/1.1/salt/ >out.txt
php -r "require_once (__DIR__.'/replace_text.php');replace_function();"
sed -e "s/database_password/${new_db_password}/" -e "s/database_user/${new_db_username}/" -e "s/database_name/${new_db_name}/" -e"s/db_host/${db_host}/" templates/DB.conf >/var/www/${domain}/wp-config.php

sudo systemctl restart nginx

echo "Setting up SSL..."
sudo certbot --nginx -d $domain

echo "Congratulations your website is up and running!. Please visit $domain"
echo "Database Credentials"
echo "Database name $new_db_name"
echo "Database user name $new_db_username"
echo "Database password $new_db_password"
echo "Note it for later reference"
