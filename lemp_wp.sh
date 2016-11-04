#!/bin/bash

# ----------------------------------------------------------------------
# | LEMP Installation Script with option of installing Wordpress.      |     
# | Created by Tad Swider - July 2016                                  |
# ----------------------------------------------------------------------

# Current user
main_user=$(whoami)
# ----------------------------------------------------------------------
# | Helper Functions                                                   |
# ----------------------------------------------------------------------

cmd_exists() {
    command -v "$1" &> /dev/null
    return $?
}
execute() {
    eval "$1" #&> /dev/null
    print_result $? "${2:-$1}"
}
ask_for_confirmation() {
    print_question "$1 (y/n) "
    read -n 1
    printf "\n"
}
answer_is_yes() {
    [[ "$REPLY" =~ ^[Yy]$ ]] \
        && return 0 \
        || return 1
}

ask_for_sudo() {

    # Ask for the administrator password upfront
    sudo -v &> /dev/null

    # Update existing `sudo` time stamp until this script has finished
    # https://gist.github.com/cowboy/3118588
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" || exit
    done &> /dev/null &

}

check_distro() {
    if [[ -r /etc/os-release ]]; then
        . /etc/os-release
        if [[ $ID = ubuntu ]]; then
            read _ UBUNTU_VERSION_NAME <<< "$VERSION"
            print_info "Running Ubuntu $UBUNTU_VERSION_NAME"
        else
            print_error "Not running an Ubuntu distribution. ID=$ID, VERSION=$VERSION"
            return 1
        fi
    else
        print_error "Not running a distribution with /etc/os-release available"
        return 1
    fi
}
cmd_exists() {
    command -v "$1" &> /dev/null
    return $?
}
ask() {
    print_question "$1"
    read -r "$2"
}
ask_with_default() {
    print_question "$1"
    read -r -e -i "$2" "$3"
}
get_answer() {
    printf "$REPLY"
}
print_error() {
    print_in_red "  [✖] $1 $2\n"
}
print_in_green() {
    printf "\e[0;32m$1\e[0m"
}
print_in_purple() {
    printf "\e[0;35m$1\e[0m"
}
print_in_red() {
    printf "\e[0;31m$1\e[0m"
}
print_in_yellow() {
    printf "\e[0;33m$1\e[0m"
}
print_info() {
    print_in_purple "\n $1\n\n"
}
print_question() {
    print_in_yellow "  [?] $1"
}
print_result() {
    [ $1 -eq 0 ] \
        && print_success "$2" \
        || print_error "$2"

    return $1
}
print_success() {
    print_in_green "  [✔] $1\n"
}

install_package() {

    declare -r PACKAGE="$2"
    declare -r PACKAGE_READABLE_NAME="$1"

    if ! package_is_installed "$PACKAGE"; then
        execute "sudo apt-get install -y $PACKAGE" "$PACKAGE_READABLE_NAME"
        #                                      suppress output ─┘│
        #            assume "yes" as the answer to all prompts ──┘
    else
        print_success "$PACKAGE_READABLE_NAME"
    fi
}

package_is_installed() {
    dpkg -s "$1" &> /dev/null
}
mkd() {
    if [ -n "$1" ]; then
        if [ -e "$1" ]; then
            if [ ! -d "$1" ]; then
                print_error "$1 - a file with the same name already exists!"
            else
                print_success "$1"
            fi
        else
            execute "mkdir -p $1" "$1"
        fi
    fi
}
nginx_site() {
echo -e '
server {
    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;

    root /var/www/custom_name;
    index index.php index.html index.htm;

    server_name custom_name;

    location / {
            # try_files $uri $uri/ =404;
            try_files $uri $uri/ /index.php?q=$uri&$args;
    }

    error_page 404 /404.html;

    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
            root /usr/share/nginx/html;
    }

    location = /favicon.ico { log_not_found off; access_log off; }
    location = /robots.txt { log_not_found off; access_log off; allow all; }
    location ~* \.(css|gif|ico|jpeg|jpg|js|png)$ {
        expires max;
        log_not_found off;

    }

    location ~ \.php$ {
            try_files $uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass unix:/var/run/php5-fpm.sock;
            fastcgi_index index.php;
            include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}'
}
outside_ip() {
    print_in_yellow "curl -s icanhazip.com"
}
# ----------------------------------------------------------------------
# | Main                                                               |
# ----------------------------------------------------------------------

main() {

    # Ensure the OS is supported
    check_distro || exit 1
    
    # Ask for MySQL root password
    ask 'Please input MySQL root password: ' 'root_pass'
        while [[ -z "$root_pass" ]] # -z "is empty"
        do
          read -r -s -p "Root password cannot be blank. Enter new password: " root_pass
        done

    # Ask for Domain
    ask 'Please provide a domain name (Ex. mysite.com): ' 'domain_name'
    
    # Ask if Wordpress to be installed
    ask_for_confirmation "Would you like to install Wordpress at this time"

    if answer_is_yes; then
        wp_install=yes
         
        ask_with_default 'Wordpress database name: ' 'wordpress' 'db_name_wp'
        db_name_wp=${db_name_wp:-"wordpress"} # Wordpress Database Name

        ask_with_default 'Wordpress database user: ' 'wordpressuser' 'db_user_wp'
        db_user_wp=${db_user_wp:-"wordpressuser"} # Wordpress Database User
       
        # Ask for Wordpress user (wordpressuser) password
        ask 'Wordpress database user password: ' 'db_wpuser_pass'
        #read -r -p "Wordpress Database user (wordpress) Password: " db_wpuser_pass
            while [[ -z "$db_wpuser_pass" ]] # -z "is empty"
            do
              read -r -s -p "User password cannot be blank. Enter new password: " db_wpuser_pass
            done
    else
        wp_install=no
        # Create PHP Info page and empty directory
        execute "echo '<?php phpinfo(); ?>' | sudo tee /srv/www/$domain_name/checkinfo.php"
    fi

    # Ask for sudo
    ask_for_sudo
    
    # Create folder under /var/www
    print_info "Creating $domain_name directory..."
    if [[ ! -d "/var/www/$domain_name" ]]; then
        execute "sudo mkdir /var/www/$domain_name"
    else
        print_success "Directory /var/wwww/$domain_name already exists"
    fi
    print_result $? "Create $domain_name directory" || exit 1
  
    # Edit Nginx config
    print_info "Installing and editing Nginx config..."
    install_package 'Nginx' 'nginx'
    nginx_site | sudo tee 1> /dev/null /etc/nginx/sites-available/$domain_name
    print_result $? "Set Nginx site" || exit 1
    execute "sudo sed -i -e "s/custom_name/"$domain_name"/g" /etc/nginx/sites-available/$domain_name" || exit 1
    execute "sudo ln -sf /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/$domain_name" || exit 1
    sudo service nginx restart &> /dev/null
    print_result $? "Restart Nginx"    
    # MySQL db_name_wp Setup
    print_info "Installing and configuring MySQL Server..."
    #sudo export DEBIAN_FRONTEND=noninteractive
    if ! package_is_installed mysql-server-5.6; then
        echo "mysql-server-5.6 mysql-server/root_password password $root_pass" | sudo debconf-set-selections
        echo "mysql-server-5.6 mysql-server/root_password_again password $root_pass" | sudo debconf-set-selections
        install_package 'MySQL Server' 'mysql-server-5.6' || exit 1
        sudo service mysql restart
        print_result $? "Nginx restart"
    else
        print_success "MysSQL Server 5.6 already installed"
    fi    
    
    print_info "Automating MySQL secure installation..."
    # mysql -u root -p"$root_pass" -e "$sqlsetup" || exit 1
    mysql -u root -p"$root_pass" -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
    mysql -u root -p"$root_pass" -e "DELETE FROM mysql.user WHERE User='';"
    mysql -u root -p"$root_pass" -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    mysql -u root -p"$root_pass" -e "DROP DATABASE IF EXISTS test;FLUSH PRIVILEGES;"
    print_result $? "MySQL secure installation" || exit 1
    if [[ $wp_install == 'yes' ]]; then
        print_info "Creating Wordpress database and user..."
        #login to MySQL, add database, add user and grant permissions
        mysql -u root -p"$root_pass" -e "CREATE DATABASE IF NOT EXISTS $db_name_wp DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
        mysql -u root -p"$root_pass" -e "GRANT ALL PRIVILEGES ON $db_name_wp.* TO $db_user_wp@localhost IDENTIFIED BY '$db_wpuser_pass';FLUSH PRIVILEGES;"
        print_result $? "Wordpress database setup" || exit 1
    fi

    # Install and configure PHP
    print_info "Installing PHP Components..."
    install_package 'php5-curl' 'php5-curl'
    install_package 'php5-fpm' 'php5-fpm'
    install_package 'php5-gd ' 'php5-gd'
    install_package 'php5-mysqlnd-' 'php5-mysqlnd'
    #install_package 'php5-mbstring' 'php5-mbstring'
    install_package 'php5-mcrypt' 'php5-mcrypt'
    install_package 'php5-cli' 'php5-cli'
    #install_package 'php5-xml' 'php5-xml'
    #install_package 'php5-xmlrpc' 'php5-xmlrpc'

    # Edit php.ini
    execute "sudo sed -i -e 's/2M/10M/g' /etc/php5/fpm/php.ini"
    execute "sudo service php5-fpm restart"
    
    # Download and setup Wordpress
    if [[ $wp_install == 'yes' ]]; then
        print_info "Downloading and configuring Wordpress..."
        wget https://wordpress.org/latest.tar.gz && tar -zxf latest.tar.gz
        execute "sudo rm -rf /var/www/$domain_name/*" && execute "sudo mv wordpress/* /var/www/$domain_name/"
        print_result $? "Move Wordpress files to $domain_name" || exit 1
        execute "sudo mv -f /var/www/$domain_name/wp-config-sample.php /var/www/$domain_name/wp-config.php"
        print_result $? "Move wp-config"
        execute "rm -f latest.tar*" # Cleanup
        
        #set database details with perl find and replace
        perl -pi -e "s/database_name_here/"$db_name_wp"/g" /var/www/$domain_name/wp-config.php
        perl -pi -e "s/username_here/"$db_user_wp"/g" /var/www/$domain_name/wp-config.php
        sudo sed -i -e "s/password_here/"$db_wpuser_pass"/g" /var/www/$domain_name/wp-config.php
        #perl -pi -e "s/password_here/'$db_wpuser_pass'/g" /var/www/$domain_name/wp-config.php # Need to find a password solution
        print_result $? "Wordpress wp-config" || exit 1
        #set WP salts
        print_info "Generating Wordpress Salts..."
        perl -i -pe'
          BEGIN {
            @chars = ("a" .. "z", "A" .. "Z", 0 .. 9);
            push @chars, split //, "!@#$%^&*()-_ []{}<>~\`+=,.;:/?|";
            sub salt { join "", map $chars[ rand @chars ], 1 .. 64 }
          }
          s/put your unique phrase here/salt()/ge
        ' /var/www/$domain_name/wp-config.php 
        print_result $? 'Generate Salts' || exit 1

        #create uploads folder and set permissions
        print_info "Folder permissions"
        execute "sudo mkdir /var/www/$domain_name/wp-content/uploads"
        execute "sudo chown -R $main_user:$main_user /var/www/$domain_name"
        execute "sudo chown -R www-data:www-data /var/www/$domain_name/wp-content"
        execute "sudo chmod 775 /var/www/$domain_name/wp-content/uploads"
        sudo service nginx restart &> /dev/null
        print_result $? "Nginx restart"
        print_in_green "Installation Complete. To finish your Wordpress installaiton go to: " outside_ip
    else

        print_in_green "LEMP Installation Comple. View your website at: " outside_ip
    fi
        
}

main
