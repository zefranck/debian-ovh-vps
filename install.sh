#!/bin/bash

#
# edit this
#

# the email we will send the mysql password to
USR_EMAIL=""

# can be replaced with the hostname you want to use instead of the ovh default one
# be sure that it has been declared in your dns zone
HOST_NAME="$(hostname)"

# mailgun domain credentials (create an account here: http://www.mailgun.com/)
SMTP_LOGIN=""
SMTP_PASS=""
SMTP_HOST="smtp.mailgun.org"

# the passphrase to generate your ssh key
SSH_PASSPHRASE=""

## =======================================================================================
##
## nothing to do below, just run the script and... voilà!
##
## =======================================================================================

##
## var automatically filed
##

USR_IP="${SSH_CLIENT%% *}"
MYSQL_PASSWORD=$(openssl rand -base64 8)

##
## Are you root?
##

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

##
## Do I have all the necessary infos?
##

if [ "$USR_EMAIL" = "" ]; then
   echo "Some data are missing, please give me your email at the beginning of the script" 1>&2
   exit 1
fi

##
## functions
##

log ()
{
	clear
	sleep 1
	echo  ":: $1"
	sleep 4
}

##
## init and basic tools
##

export LC_ALL=C
apt-get update && apt-get upgrade --yes
apt-get install --yes git curl mlocate dnsutils

hostname $HOST_NAME

##
## Makes terminal prettier
## 

curl https://gist.githubusercontent.com/zefranck/0a9f88c03b5a885c8cca9acfaed6fd11/raw/19717cbc619846cdc23bb679911accba98a12264/.bashrc > ~/.bashrc
source ~/.bashrc

##
## locales
##

locale-gen en_US.UTF-8 fr_FR.UTF-8

echo "" >> ~/.bashrc
echo "# Locales" >> ~/.bashrc
echo "export LANGUAGE=fr_FR.UTF-8" >> ~/.bashrc
echo "export LANG=fr_FR.UTF-8" >> ~/.bashrc
echo "export LC_ALL=C" >> ~/.bashrc
echo "" >> ~/.bashrc

source ~/.bashrc

##
## add iTerm integration //todo: if needed only//
## https://iterm2.com/

cd ~
curl -L https://iterm2.com/misc/install_shell_integration_and_utilities.sh | bash

##
## let's encrypt (cerbot)
##

echo "deb ftp://ftp.fr.debian.org/debian jessie-backports main" >> /etc/apt/sources.list
apt-get update
apt-get install certbot -t --yes jessie-backports

##
## nginx 
##

log 'Installing secured nginx (thanx to https://www.nicolas-simond.com/)'

cd /tmp && wget --no-check-certificate https://raw.githubusercontent.com/stylersnico/nginx-openssl-chacha/master/build.sh && chmod +x build.sh && ./build.sh

mkdir /etc/nginx/sites-available/ /etc/nginx/sites-enabled/ -p
curl https://gist.githubusercontent.com/zefranck/0a9f88c03b5a885c8cca9acfaed6fd11/raw/07c81dc718831f4c5b5a403320e3b7a3474e7bd0/default%2520nginx%2520vhost > /etc/nginx/sites-available/default
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/

chsh -s /bin/bash www-data

install -d -o www-data -g www-data -m 755 /var/www/vhosts
install -d -o www-data -g www-data -m 755 /var/www/vhosts/html
install -d -o www-data -g www-data -m 755 /var/www/.ssh/
cp /root/.bashrc /var/www/ 

chown www-data:www-data /var/www -R
su -c "cd ~ && curl -L https://iterm2.com/misc/install_shell_integration_and_utilities.sh | bash" www-data

##
## php
## apt-cache search php7-*
##

log 'Installing php 7 and composer'

echo "deb http://packages.dotdeb.org jessie all" > /etc/apt/sources.list.d/dotdeb.list
wget -O- https://www.dotdeb.org/dotdeb.gpg | apt-key add -

apt-get update

apt-get install -y \
	php7.0-cli php7.0-curl php7.0-dev php7.0-zip php7.0-fpm \
	php7.0-gd php7.0-xml php7.0-mysql php7.0-mcrypt php7.0-mbstring php7.0-opcache php7.0-memcache php7.0-mongo

curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

##
## let's make ngninx and php work together
##

log 'Configuring nginx and php together'

#below is useless: https://www.nginx.com/resources/wiki/start/topics/examples/phpfcgi/
#sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/7.0/fpm/php.ini

sed -i "s/listen =.*/listen = 127.0.0.1:9000/" /etc/php/7.0/fpm/pool.d/www.conf

# get default website
curl https://gist.githubusercontent.com/zefranck/0a9f88c03b5a885c8cca9acfaed6fd11/raw/5a2891378d2a7239366b22e1a1805770e0fc6303/default%2520nginx%2520host > /etc/nginx/sites-available/default

## create default page
SCRIPT="$(cat << \EOF
echo "<?php if (isset(\$_GET['info'])) phpinfo();" > /var/www/vhosts/html/index.php
EOF
)"
su -c "$SCRIPT" www-data

## restart nginx and fpm

service php7.0-fpm restart
service nginx restart

##
## email
##

log "Installing email using mailgun (because I don't want my server to send emails directly)"

debconf-set-selections <<< "postfix postfix/mailname string $(hostname)"
debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"

apt-get install mailutils -y
apt-get install postfix libsasl2-modules -y

# Configuration for the script

POSTFIX_CONFIG=/etc/postfix/main.cf
POSTFIX_SASL=/etc/postfix/sasl_passwd

# Set a safe umask
umask 077

# Comment out a couple transport configurations

sed -i.bak "s/default_transport = error/# default_transport = error/g" $POSTFIX_CONFIG
sed -i.bak "s/relay_transport = error/# relay_transport = error/g" $POSTFIX_CONFIG
sed -i.bak "s/relayhost =/# relayhost =/g" $POSTFIX_CONFIG

# Add the relay host for Mailgun, force SSL/TLS, and other config
cat >> $POSTFIX_CONFIG << EOF

relayhost = [$SMTP_HOST]:2525
smtp_tls_security_level = encrypt
smtp_sasl_auth_enable = yes
smtp_sasl_password_maps = static:$SMTP_LOGIN:$SMTP_PASS
smtp_sasl_security_options = noanonymous
EOF

# Reload Postfix
/etc/init.d/postfix restart

echo "$(hostname) :: email testing" | mail -s "$(hostname) :: email testing" $USR_EMAIL

##
## Database and memory caching
##

log 'Installing mysql'

MYSQLPASSWORD=$(openssl rand -base64 8)

debconf-set-selections <<< "mariadb-server mysql-server/root_password password $MYSQLPASSWORD"
debconf-set-selections <<< "mariadb-server mysql-server/root_password_again password $MYSQLPASSWORD"

apt-get -y install software-properties-common
apt-get install -y mariadb-server mariadb-client

echo "$(hostname) MySQL server has been installed with password: $MYSQLPASSWORD" | mail -s "$(hostname) :: MySQL installed" $USR_EMAIL

# memcache

log 'Installing memcache'

apt-get install -y memcached

# Mongodb

log 'Installing mongo'

apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 0C49F3730359A14518585931BC711F9BA15703C6
echo "deb http://repo.mongodb.org/apt/debian jessie/mongodb-org/3.4 main" | tee /etc/apt/sources.list.d/mongodb-org-3.4.list
apt-get update
apt-get install -y mongodb-org

curl https://raw.githubusercontent.com/mongodb/mongo/master/debian/init.d > /etc/init.d/mongod
chmod +x /etc/init.d/mongod

update-rc.d mongod defaults
update-rc.d mongod enable
/etc/init.d/mongod start

##
## restart nginx
##

service nginx restart
service php7.0-fpm restart

##
## firewall et sécurisation
##

log 'Securing server'

ssh-keygen -t rsa -f $HOME/.ssh/id_rsa -q -P "$SSH_PASSPHRASE" -C $(whoami)@$(hostname)

apt-get install --yes fail2ban ufw

ufw allow from $USR_IP
ufw allow from 92.222.184.0/24
ufw allow from 92.222.185.0/24
ufw allow from 92.222.186.0/24
ufw allow from 167.114.37.0/24
ufw allow from 151.80.118.87/32
ufw allow proto tcp from any to any port 80,443
ufw --force enable

##
## node
##

log 'Installing node'

apt-get install node --yes

#
# install node for user www-data
#

SCRIPT="$(cat <<EOF
cd ~
curl -sL https://raw.githubusercontent.com/creationix/nvm/v0.32.0/install.sh | sh
# This loads nvm
export NVM_DIR="/var/www/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
source .nvm/nvm.sh
nvm ls-remote
nvm install 6.9.5
npm install -g forever
EOF
)"
su -c "$SCRIPT" www-data

##
## backup
##

log 'Installing tools to backup to Amazon'

apt-get install --yes unzip links

cd /tmp
wget http://downloads.rclone.org/rclone-current-linux-amd64.zip
unzip rclone-current-linux-amd64.zip
cd rclone-v1.xx-linux-amd64
install -o root -g root -m 755 ./rclone /usr/local/bin
mkdir -p /usr/local/share/man/man1
cp rclone.1 /usr/local/share/man/man1/
mandb

##
## Final cleanup
##

log "Upgrade the system one more time if necessary"
apt-get upgrade -y

log "Autoremove useless packages"
apt-get autoremove -y

log "Clean the packages"
apt-get clean -y

log "Done!"