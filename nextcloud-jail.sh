#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 using the current release of Nextcloud 13
# https://github.com/danb35/freenas-iocage-nextcloud

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

# Initialize defaults
JAIL_IP=""
DEFAULT_GW_IP=""
INTERFACE=""
VNET="off"
POOL_PATH=""
JAIL_NAME="nextcloud"
TIME_ZONE=""
HOST_NAME=""
DB_PATH=""
FILES_PATH=""
PORTS_PATH=""
STANDALONE_CERT=0
DNS_CERT=0
TEST_CERT="--staging"
TYPE_CERT="--webroot"
C_NAME="US"
ST_NAME=""
L_NAME=""
O_NAME=""
OU_NAME=""
EMAIL_NAME=""
NO_SSL=""

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/nextcloud-config
CONFIGS_PATH=$SCRIPTPATH/configs
DB_ROOT_PASSWORD=$(openssl rand -base64 16)
DB_PASSWORD=$(openssl rand -base64 16)
ADMIN_PASSWORD=$(openssl rand -base64 12)
#RELEASE=$(freebsd-version | sed "s/STABLE/RELEASE/g")
RELEASE="11.3-RELEASE"
# Check for nextcloud-config and set configuration
if ! [ -e $SCRIPTPATH/nextcloud-config ]; then
  echo "$SCRIPTPATH/nextcloud-config must exist."
  exit 1
fi

# Check that necessary variables were set by nextcloud-config
if [ -z $JAIL_IP ]; then
  echo 'Configuration error: JAIL_IP must be set'
  exit 1
fi
if [ -z $DEFAULT_GW_IP ]; then
  echo 'Configuration error: DEFAULT_GW_IP must be set'
  exit 1
fi
if [ -z $INTERFACE ]; then
  echo 'Configuration error: INTERFACE must be set'
  exit 1
fi
if [ -z $POOL_PATH ]; then
  echo 'Configuration error: POOL_PATH must be set'
  exit 1
fi
if [ -z $TIME_ZONE ]; then
  echo 'Configuration error: TIME_ZONE must be set'
  exit 1
fi
if [ -z $HOST_NAME ]; then
  echo 'Configuration error: HOST_NAME must be set'
  exit 1
fi
if [ $STANDALONE_CERT -eq 0 ] && [ $DNS_CERT -eq 0 ]; then
  echo 'Configuration error: Either STANDALONE_CERT or DNS_CERT'
  echo 'must be set to 1.'
  exit 1
fi
if [ $DNS_CERT -eq 1 ] && ! [ -x $CONFIGS_PATH/acme_dns_issue.sh ]; then
  echo 'If DNS_CERT is set to 1, configs/acme_dns_issue.sh must exist'
  echo 'and be executable.'
  exit 1
fi

# If DB_PATH, FILES_PATH, and PORTS_PATH weren't set in nextcloud-config, set them
if [ -z $DB_PATH ]; then
  DB_PATH="${POOL_PATH}/nextcloud/db"
fi
if [ -z $FILES_PATH ]; then
  FILES_PATH="${POOL_PATH}/nextcloud/files"
fi
if [ -z $PORTS_PATH ]; then
  PORTS_PATH="${POOL_PATH}/portsnap"
fi

# Sanity check DB_PATH, FILES_PATH, and PORTS_PATH -- they all have to be different,
# and can't be the same as POOL_PATH
if [ "${DB_PATH}" = "${FILES_PATH}" ] || [ "${FILES_PATH}" = "${PORTS_PATH}" ] || [ "${PORTS_PATH}" = "${DB_PATH}" ]
then
  echo "DB_PATH, FILES_PATH, and PORTS_PATH must all be different!"
  exit 1
fi

if [ "${DB_PATH}" = "${POOL_PATH}" ] || [ "${FILES_PATH}" = "${POOL_PATH}" ] || [ "${PORTS_PATH}" = "${POOL_PATH}" ] 
then
  echo "DB_PATH, FILES_PATH, and PORTS_PATH must all be different"
  echo "from POOL_PATH!"
  exit 1
fi

# Make sure DB_PATH is empty -- if not, MariaDB will choke
if [ "$(ls -A $DB_PATH)" ]; then
  echo "$DB_PATH is not empty!"
  echo "DB_PATH must be empty, otherwise this script will break your existing database."
  exit 1
fi
#openssl parameters
if [ -z $C_NAME ]; then
echo 'Configuration error: C_NAME must be set'
exit 1
fi
    
if [ -z $ST_NAME ]; then
echo 'Configuration error: ST_NAME must be set'
exit 1
fi
        
if [ -z $L_NAME ]; then
echo 'Configuration error: L_NAME must be set'
exit 1
fi
            
if [ -z $O_NAME ]; then
echo 'Configuration error: O_NAME must be set'
exit 1
fi
                
if [ -z $OU_NAME ]; then
echo 'Configuration error: OU_NAME must be set'
exit 1
fi

if [ -z $EMAIL_NAME ]; then
echo 'Configuration error: OU_NAME must be set'
exit 1
fi
echo $NO_SSL
if [ -z $NO_SSL ]; then
NO_SSL="no"
fi 

echo '{"pkgs":["nano","rsync","openssl","curl","sudo","php73-phar","py37-certbot","nginx","mariadb102-server","redis","php73-ctype","php73-dom","php73-gd","php73-iconv","php73-json","php73-mbstring","php73-posix","php73-simplexml","php73-xmlreader","php73-xmlwriter","php73-zip","php73-zlib","php73-pdo_mysql","php73-hash","php73-xml","php73-session","php73-mysqli","php73-wddx","php73-xsl","php73-filter","php73-curl","php73-fileinfo","php73-bz2","php73-intl","php73-openssl","php73-ldap","php73-ftp","php73-imap","php73-exif","php73-gmp","php73-memcache","php73-opcache","php73-pcntl","php73","mod_php73","php73-pecl-APCu","php73-pecl-imagick","bash","p5-Locale-gettext","help2man","texinfo","m4","autoconf","socat","git","perl5"]}' > /tmp/pkg.json
iocage create --name "${JAIL_NAME}" -p /tmp/pkg.json -r ${RELEASE} ip4_addr="${INTERFACE}|${JAIL_IP}/24" defaultrouter="${DEFAULT_GW_IP}" boot="on" host_hostname="${JAIL_NAME}" vnet="${VNET}" allow_raw_sockets=1

rm /tmp/pkg.json

mkdir -p ${DB_PATH}/
chown -R 88:88 ${DB_PATH}/
mkdir -p ${FILES_PATH}
chown -R 80:80 ${FILES_PATH}
mkdir -p ${PORTS_PATH}/ports
mkdir -p ${PORTS_PATH}/db
mkdir -p ${POOL_PATH}/media
mkdir -p ${POOL_PATH}/NextcloudBackups

iocage exec "${JAIL_NAME}" mkdir -p /mnt/configs
iocage exec "${JAIL_NAME}" mkdir -p /usr/local/www
#mkdir -p /mnt/iocage/jails/${JAIL_NAME}/root/var/db/portsnap
#mkdir -p /mnt/iocage/jails/${JAIL_NAME}/root/mnt/files
#mkdir -p /mnt/iocage/jails/${JAIL_NAME}/root/mnt/configs
iocage exec "${JAIL_NAME}" mkdir -p /usr/ports
iocage exec "${JAIL_NAME}" mkdir -p /mnt/NextcloudBackups
iocage exec "${JAIL_NAME}" mkdir -p /mnt/media

iocage exec ${JAIL_NAME} mkdir -p /mnt/files
iocage exec ${JAIL_NAME} mkdir -p /var/db/mysql
iocage exec ${JAIL_NAME} mkdir -p /mnt/configs
iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/ports /usr/ports nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${PORTS_PATH}/db /var/db/portsnap nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${FILES_PATH} /mnt/files nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${DB_PATH} /var/db/mysql  nullfs  rw  0  0
iocage fstab -a ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/media /mnt/media nullfs rw 0 0
iocage fstab -a ${JAIL_NAME} ${POOL_PATH}/NextcloudBackups /mnt/NextcloudBackups nullfs rw 0 0
iocage exec ${JAIL_NAME} chown -R www:www /mnt/files
iocage exec ${JAIL_NAME} chmod -R 770 /mnt/files
#iocage exec ${JAIL_NAME} "if [ -z /usr/ports ]; then portsnap fetch extract; else portsnap auto; fi"
iocage exec ${JAIL_NAME} chsh -s /usr/local/bin/bash root
iocage exec ${JAIL_NAME} fetch -o /tmp https://download.nextcloud.com/server/releases/latest.tar.bz2
#iocage exec ${JAIL_NAME} fetch -o /tmp https://download.nextcloud.com/server/releases/nextcloud-18.0.2.tar.bz2
#iocage exec ${JAIL_NAME} tar xjf /tmp/nextcloud-18.0.2.tar.bz2 -C /usr/local/www/
iocage exec ${JAIL_NAME} tar xjf /tmp/latest.tar.bz2 -C /usr/local/www/
iocage exec ${JAIL_NAME} rm /tmp/latest.tar.bz2
iocage exec ${JAIL_NAME} chown -R www:www /usr/local/www/nextcloud/
iocage exec ${JAIL_NAME} sysrc nginx_enable="YES"
iocage exec ${JAIL_NAME} sysrc mysql_enable="YES"
iocage exec ${JAIL_NAME} sysrc redis_enable="YES"
iocage exec ${JAIL_NAME} sysrc php_fpm_enable="YES"
iocage exec ${JAIL_NAME} -- mkdir -p /usr/local/etc/nginx/ssl/

#iocage exec ${JAIL_NAME} 'echo 'DEFAULT_VERSIONS+=ssl=openssl' >> /etc/make.conf'
#iocage exec ${JAIL_NAME} portsnap fetch extract
#iocage exec ${JAIL_NAME} make -C /usr/ports/databases/pecl-redis clean install BATCH=yes
#iocage exec ${JAIL_NAME} make -C /usr/ports/devel/pecl-APCu clean install BATCH=yes
  
# Copy and edit pre-written config files

if [ $NO_SSL = "yes" ]; then
   iocage exec ${JAIL_NAME} cp -f /mnt/configs/nginx.basic.conf /usr/local/etc/nginx/nginx.conf
   echo "NO_SSL=${NO_SSL}"
else
   iocage exec ${JAIL_NAME} mkdir -p /usr/local/etc/nginx/ssl/
   echo "make directory /usr/local/etc/nginx/ssl/"
   iocage exec ${JAIL_NAME} -- openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /usr/local/etc/nginx/ssl/nginx-selfsigned.key -out /usr/local/etc/nginx/ssl/nginx-selfsigned.crt -subj "/C=${C_NAME}/ST=$P{ST_NAME}/L=${L_NAME}/O=${O_NAME}/OU={OU_NAME}/CN={HOST_NAME}"
   echo "openssl key generated"
   iocage exec ${JAIL_NAME} -- openssl dhparam -out /usr/local/etc/nginx/ssl/dhparam.pem 2048
   echo "dhparam done"
   iocage exec ${JAIL_NAME} cp -f /mnt/configs/nginx.conf /usr/local/etc/nginx/nginx.conf
fi

iocage exec ${JAIL_NAME} cp -f /mnt/configs/php.ini /usr/local/etc/php.ini
iocage exec ${JAIL_NAME} cp -f /mnt/configs/redis.conf /usr/local/etc/redis.conf      
iocage exec ${JAIL_NAME} cp -f /mnt/configs/www.conf /usr/local/etc/php-fpm.d/
iocage exec ${JAIL_NAME} cp -f /usr/local/share/mysql/my-small.cnf /var/db/mysql/my.cnf
iocage exec ${JAIL_NAME} sed -i '' "s/yourhostnamehere/${HOST_NAME}/" /usr/local/etc/nginx/nginx.conf
iocage exec ${JAIL_NAME} sed -i '' "s/youripaddress/${JAIL_IP}/" /usr/local/etc/nginx/nginx.conf
#iocage exec ${JAIL_NAME} sed -i '' "s/#skip-networking/skip-networking/" /var/db/mysql/my.cnf
#iocage exec ${JAIL_NAME} sed -i '' "s|mytimezone|${TIME_ZONE}|" /usr/local/etc/php.ini
#iocage exec ${JAIL_NAME} openssl dhparam -out /usr/local/etc/pki/tls/private/dhparams_4096.pem 4096
iocage restart ${JAIL_NAME}

if [ $NO_SSL = "yes" ]; then
   echo "NO_SSL check yes"
else
   #iocage exec ${JAIL_NAME} -- certbot certonly --debug --webroot -w /usr/local/www -d ${HOST_NAME} --agree-tos -m ${EMAIL_NAME} --no-eff-email
	if [ TYPE_CERT = "--webroot" ]; then
            iocage exec ${JAIL_NAME} -- certbot certonly ${TEST_CERT} --webroot -w /usr/local/www -d ${HOST_NAME} --agree-tos -m ${EMAIL_NAME} --no-eff-email
	else
            iocage exec ${JAIL_NAME} -- certbot certonly ${TEST_CERT} --standalone -w /usr/local/www -d ${HOST_NAME} --agree-tos -m ${EMAIL_NAME} --no-eff-email
	fi
   echo "certbot done"
fi

# Secure database, set root password, create Nextcloud DB, user, and password
iocage exec ${JAIL_NAME} mysql -u root -e "CREATE DATABASE nextcloud;"
iocage exec ${JAIL_NAME} mysql -u root -e "GRANT ALL ON nextcloud.* TO nextcloud@localhost IDENTIFIED BY '${DB_PASSWORD}';"
iocage exec ${JAIL_NAME} mysql -u root -e "DELETE FROM mysql.user WHERE User='';"
iocage exec ${JAIL_NAME} mysql -u root -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
iocage exec ${JAIL_NAME} mysql -u root -e "DROP DATABASE IF EXISTS test;"
iocage exec ${JAIL_NAME} mysql -u root -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
iocage exec ${JAIL_NAME} mysql -u root -e "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASSWORD}') WHERE User='root';"
iocage exec ${JAIL_NAME} mysqladmin reload
iocage exec ${JAIL_NAME} cp -f /mnt/configs/my.cnf /root/.my.cnf
iocage exec ${JAIL_NAME} sed -i '' "s|mypassword|${DB_ROOT_PASSWORD}|" /root/.my.cnf

# Save passwords for later reference
iocage exec ${JAIL_NAME} echo "MySQL root password is ${DB_ROOT_PASSWORD}" > /root/${JAIL_NAME}_db_password.txt
iocage exec ${JAIL_NAME} echo "Nextcloud database password is ${DB_PASSWORD}" >> /root/${JAIL_NAME}_db_password.txt
iocage exec ${JAIL_NAME} echo "Nextcloud Administrator password is ${ADMIN_PASSWORD}" >> /root/${JAIL_NAME}_db_password.txt
chmod 600 /root/${JAIL_NAME}_db_password.txt

# If standalone mode was used to issue certificate, reissue using webroot
if [ $STANDALONE_CERT -eq 1 ]; then
  certbot certonly --webroot -w /usr/local/www -d ${HOST_NAME} --agree-tos -m ${EMAIL_NAME} --no-eff-email
fi

iocage exec ${JAIL_NAME} service nginx restart

iocage exec ${JAIL_NAME} su -m www -c "php /usr/local/www/nextcloud/occ maintenance:install --database=\"mysql\" --database-name=\"nextcloud\" --database-user=\"nextcloud\" --database-pass=\"${DB_PASSWORD}\" --database-host=\"localhost:/tmp/mysql.sock\" --admin-user=\"admin\" --admin-pass=\"${ADMIN_PASSWORD}\" --data-dir=\"/mnt/files\""
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set memcache.local --value="\OC\Memcache\APCu"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set redis host --value="/tmp/redis.sock"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set redis port --value=0 --type=integer'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set memcache.locking --value="\OC\Memcache\Redis"'
iocage exec ${JAIL_NAME} su -m www -c "php /usr/local/www/nextcloud/occ config:system:set trusted_domains 1 --value=\"${HOST_NAME}\""
iocage exec ${JAIL_NAME} su -m www -c "php /usr/local/www/nextcloud/occ config:system:set trusted_domains 2 --value=\"${JAIL_IP}\""
iocage exec ${JAIL_NAME} su -m www -c "php /usr/local/www/nextcloud/occ app:enable encryption"
iocage exec ${JAIL_NAME} su -m www -c "php /usr/local/www/nextcloud/occ encryption:enable"
iocage exec ${JAIL_NAME} su -m www -c "php /usr/local/www/nextcloud/occ encryption:disable"
iocage exec ${JAIL_NAME} su -m www -c "php /usr/local/www/nextcloud/occ background:cron"
iocage exec ${JAIL_NAME} crontab -u www /mnt/configs/www-crontab
iocage exec ${JAIL_NAME} crontab -u root /mnt/configs/root-crontab
iocage exec ${JAIL_NAME} su -m www -c "php /usr/local/www/nextcloud/cron.php"

iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enable_previews --value=true --type=boolean'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 0 --value="OC\Preview\PNG"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 1 --value="OC\Preview\JPEG"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 2 --value="OC\Preview\GIF"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 3 --value="OC\Preview\BMP"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 4 --value="OC\Preview\XBitmap"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 5 --value="OC\Preview\MarkDown"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 6 --value="OC\Preview\MP3"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 7 --value="OC\Preview\TXT"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 8 --value="OC\Preview\Illustrator"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 9 --value="OC\Preview\Movie"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 10 --value="OC\Preview\MSOffice2003"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 11 --value="OC\Preview\MSOffice2007"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 12 --value="OC\Preview\MSOfficeDoc"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 13 --value="OC\Preview\OpenDocument"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 14 --value="OC\Preview\PDF"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 15 --value="OC\Preview\Photoshop"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 16 --value="OC\Preview\Postscript"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 17 --value="OC\Preview\StarOffice"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 18 --value="OC\Preview\SVG"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 19 --value="OC\Preview\TIFF"'
iocage exec ${JAIL_NAME} su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set enabledPreviewProviders 20 --value="OC\Preview\Font"'
  
iocage exec ${JAIL_NAME} ln -s /usr/local/www/nextcloud/robots.txt /usr/local/www

# add media group to www user
iocage exec ${JAIL_NAME} pw groupadd -n media -g 8675309
iocage exec ${JAIL_NAME} pw groupmod media -m www
iocage restart ${JAIL_NAME} 

#
# Add Video previews
iocage exec ${JAIL_NAME} pkg install -y ffmpeg


echo
echo
echo
# copy backup and restore script and email settings script
iocage exec ${JAIL_NAME} cp -f /mnt/configs/NextcloudBR.sh /usr/NextcloudBR.sh
iocage exec ${JAIL_NAME} cp -f /mnt/configs/NextcloudBR-config /usr/NextcloudBR-config
iocage exec ${JAIL_NAME} cp -f /mnt/configs/nginx.basic.conf /usr/local/etc/nginx/nginx.conf
iocage exec ${JAIL_NAME} chmod 600 /usr/NextcloudBR-config
iocage exec ${JAIL_NAME} sed -i '' "s|mydbpassword|${DB_PASSWORD}|" /usr/NextcloudBR-config
iocage exec ${JAIL_NAME} cp -f /mnt/configs/email.sh /usr/email.sh

echo "Backup and Restore scripts copied to /usr directory in the jail ${JAIL_NAME}"

# Don't need /mnt/configs any more, so unmount it
iocage fstab -r ${JAIL_NAME} ${CONFIGS_PATH} /mnt/configs nullfs rw 0 0

# Done!
echo "##########################################################################"
echo "Installation complete!"
if [ $NO_SSL = "yes" ]; then
   echo "Using your web browser, go to https://${JAIL_IP}/nextcloud to log in"
else
   echo "Using your web browser, go to https://${HOST_NAME}/nextcloud to log in"
fi
echo "Default user is admin, password is ${ADMIN_PASSWORD}"
echo ""
echo "Database Information"
echo "--------------------"
echo "Database user = nextcloud"
echo "Database password = ${DB_PASSWORD}"
echo "The MariaDB root password is ${DB_ROOT_PASSWORD}"
echo ""
echo "All passwords are saved in /root/${JAIL_NAME}_db_password.txt"
echo "To fix the 'Some columns in the database are missing a conversion to big int' issue this command"
ehco "iocage exec ${JAIL_NAME} sudo -u www php /usr/local/www/nextcloud/occ db:convert-filecache-bigint"
