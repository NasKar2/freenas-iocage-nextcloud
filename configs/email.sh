#!/usr/local/bin/bash

#su -m www -c 'php /usr/local/www/nextcloud/occ -help'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_smtpmode --value="smtp"'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_smtpauthtype --value="LOGIN"'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_smtpsecure --value="ssl"'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_from_address --value="emailaddressbefore@"'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_domain --value="gmail.com"'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_smtpauth --value="1"'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_smtpport --value="465"'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_smtpname --value="emailaddressbefore@"'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_smtppassword --value="password"'
su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_smtphost --value="smtp.gmail.com"'

echo "email settings restored"
echo "Done"

#if [ "su -m www -c 'php /usr/local/www/nextcloud/occ config:system:get mail_smtpmode'"="" ]; then
#   echo "not set will set = value true"
#   su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set mail_smtpmode --value="smtp"'
#else
#   echo "set = value false"
#fi


