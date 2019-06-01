#!/usr/local/bin/bash

#
# Bash script for making backups of Nextcloud.
# Usage: ./NextcloudBackup.sh <dbPassword> (e.g. ./NextcloudRestore.sh <dbPassword>)
#
# The script is based on an installation of Nextcloud using nginx and MariaDB, see https://github.com/NasKar2/freenas-iocage-nextcloud
# This script should be run in the nextcloud jail and assumes you have mounted /mnt/v1/NextcloudBackups to /mnt/NextcloudBackups to store backups
# If you ran the install script for nextcloud referenced above it will be done already

# This script was adapted from https://github.com/DecaTec/Nextcloud-Backup-Restore
#

#
# IMPORTANT
# You have to customize this script (directories, users, etc.) for your actual environment.
# All entries which need to be customized are tagged with "TODO".
#

#!/bin/sh
# Build an iocage jail under FreeNAS 11.1 using the current release of Nextcloud 13
# https://github.com/danb35/freenas-iocage-nextcloud

# Check for root privileges
if ! [ $(id -u) = 0 ]; then
   echo "This script must be run with root privileges"
   exit 1
fi

# current date
currentDate=$(date +"%Y%m%d_%H%M%S")

# Initialize defaults
# Variables
backupMainDir="/mnt/NextcloudBackups" #The directory where you store the Nextcloud backups
backupdir="${backupMainDir}/${currentDate}/" # The actual directory of the current backup - this is is subdirectory of the main directory above with a timestamp
nextcloudFileDir="/usr/local/www/nextcloud" # The directory of your Nextcloud installation (this is a directory under your web root)
nextcloudDataDir="/mnt/files" # The directory of your Nextcloud data directory (outside the Nextcloud file directory)
webserverServiceName="nginx" # The service name of the web server. Used to start/stop web server (e.g. 'service <webserverServiceName> start')
nextcloudDatabase="nextcloud" # Your Nextcloud database name
dbUser="nextcloud" # Your Nextcloud database user
dbPassword="" # The password of the Nextcloud database user
webserverUser="www" # Your web server user
maxNrOfBackups=3 # The maximum number of backups to keep (when set to 0, all backups are kept)

# File names for backup files
# If you prefer other file names, you'll also have to change the NextcloudRestore.sh script.
fileNameBackupFileDir="nextcloud-filedir.tar.gz"
fileNameBackupDataDir="nextcloud-datadir.tar.gz"
fileNameBackupDb="nextcloud-db.sql"

SCRIPT=$(readlink -f "$0")
SCRIPTPATH=$(dirname "$SCRIPT")
. $SCRIPTPATH/NextcloudBR-config
CONFIGS_PATH=$SCRIPTPATH/configs
DB_ROOT_PASSWORD=$(openssl rand -base64 16)
DB_PASSWORD=$(openssl rand -base64 16)
ADMIN_PASSWORD=$(openssl rand -base64 12)

# Check for NextcloudBR-config and set configuration
if ! [ -e $SCRIPTPATH/NextcloudBR-config ]; then
  echo "$SCRIPTPATH/NextcloudBR-config must exist."
  exit 1
fi

# Check that necessary variables were set by NextcloudBR-config
if [ -z $backupMainDir ]; then
  echo 'Configuration error: backupMainDir must be set'
  exit 1
fi

if [ -z $backupdir ]; then
  echo 'Configuration error: backupdir must be set'
  exit 1
fi

if [ -z $nextcloudFileDir ]; then
  echo 'Configuration error: nextcloudFileDir must be set'
  exit 1
fi

if [ -z $nextcloudDataDir ]; then
  echo 'Configuration error: nextcloudDataDir must be set'
  exit 1
fi
if [ -z $webserverServiceName ]; then
  echo 'Configuration error: webserverServiceName must be set'
  exit 1
fi

if [ -z $nextcloudDatabase ]; then
  echo 'Configuration error: nextcloudDatabase must be set'
  exit 1
fi
if [ -z $dbUser ]; then
  echo 'Configuration error: dbUser must be set'
  exit 1
fi

if [ -z $dbPassword ]; then
  echo 'Configuration error: dbPassword must be set'
  exit 1
fi

if [ -z $webserverUser ]; then
  echo 'Configuration error: webserverUser must be set'
  exit 1
fi
if [ -z $fileNameBackupFileDir ]; then
  echo 'Configuration error: fileNameBackupFileDir must be set'
  exit 1
fi

if [ -z $fileNameBackupDataDir ]; then
  echo 'Configuration error: fileNameBackupDataDir must be set'
  exit 1
fi

if [ -z $fileNameBackupDb ]; then
  echo 'Configuration error: fileNameBackupDb must be set'
  exit 1
fi

#echo $backupMainDir
#echo $backupdir
#echo $nextcloudFileDir
#echo $nextcloudDataDir
#echo $webserverServiceName
#echo $nextcloudDatabase
#echo $dbUser
#echo $dbPassword
#echo $webserverUser
#echo $fileNameBackupFileDir
#echo $fileNameBackupDataDir
#echo $fileNameBackupDb

#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
	errorecho "ERROR: This script has to be run as root!"
	exit 1
fi

if [ "$cron" != "yes" ]; then
 read -p "Enter '(B)ackup' to backup Nextcloud or '(R)estore' to restore Nextcloud: " choice
fi
echo

if [ "${cron}" == "yes" ]; then
    choice="B"
fi
echo
if [ ${choice} == "B" ] || [ ${choice} == "b" ]; then


#
# Check if backup dir already exists
#
if [ ! -d "${backupdir}" ]; then
	mkdir -p "${backupdir}"
else
	errorecho "ERROR: The backup directory ${backupdir} already exists!"
	exit 1
fi

#
# Set maintenance mode
#
echo "Set maintenance mode for Nextcloud..."
#cd "${nextcloudFileDir}"
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --on'
#su -m "${webserverUser}" php /usr/local/www occ maintenance:mode --on
echo "Done"
echo

#
# Stop web server
#
echo "Stopping web server..."
service "${webserverServiceName}" stop
echo "Done"
echo

#
# Backup file and data directory
#
echo "Creating backup of Nextcloud file directory..."
tar -cpzf "${backupdir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}" .
#mkdir -p "${backupdir}nextcloud/"
#rsync -avx "${nextcloudFileDir}/" "${backupdir}nextcloud/"
echo "Done"
echo

echo "Creating backup of Nextcloud data directory..."
tar -cpzf "${backupdir}/${fileNameBackupDataDir}"  -C "${nextcloudDataDir}" .
#mkdir -p "${backupdir}/files/"
#rsync -avx "${nextcloudDataDir}/" "${backupdir}files/"
echo "Done"
echo

#
# Backup DB
#
echo "Backing up Nextcloud Database..."
mysqldump --single-transaction -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" > "${backupdir}/${fileNameBackupDb}"
echo "Done"
echo

#
# Start web server
#
echo "Starting web server..."
service "${webserverServiceName}" start
echo "Done"
echo

#
# Disable maintenance mode
#
echo "Switching off maintenance mode..."
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --off'
#su -m "${webserverUser}" php /usr/local/www occ maintenance:mode --off
echo "Done"
echo

#
# Delete old backups
#
#maxNrOfBackups=3
#nrOfBackups=0
#backupMainDir="/mnt/files/NextcloudBackups/"
#echo "before if"
#echo $maxNrOfBackups
if [ ${maxNrOfBackups} -ne 0 ]
then
     echo "maxNrOfBackups is not 0"
        nrOfBackups="$(ls -l ${backupMainDir} | grep -c ^d)"
     echo "nrOfBackups=" $nrOfBackups
        nDirToRemove="$((nrOfBackups - maxNrOfBackups))"

     echo "nDirToRemove=" $nDirToRemove

while [ $nDirToRemove -gt 0 ]
do
echo
echo "number dir to remove=" $nDirToRemove
dirToRemove="$(ls -t ${backupMainDir} | tail -1)"
echo "Removing Directory ${dirToRemove}"
nDirToRemove="$((nDirToRemove - 1))"
rm -r ${backupMainDir}/${dirToRemove}
done
fi

echo
echo "DONE!"
echo "Backup created: ${backupdir}"
exit 1

elif [ $choice == "R" ] || [ $choice == "r" ]; then

#
# Pick the restore directory *don't edit this section*
#
cd $backupMainDir
shopt -s dotglob
shopt -s nullglob
array=(*)
for dir in "${array[@]}"; do echo; done
 
for dir in */; do echo; done
 
echo "There are ${#array[@]} backups available pick the one to restore"; \
select dir in "${array[@]}"; do echo; break; done

echo "You choose ${dir}"


# More Variables
restore=$dir
currentRestoreDir="${backupMainDir}/${restore}"
#echo $currentRestoreDir

#
# Check if currentRestoreDir exists
#
if [ ! -d "${currentRestoreDir}" ]
then
	 echo "ERROR: Backup ${restore} not found!"
    exit 1
fi

#
# Set maintenance mode
#
echo "Set maintenance mode for Nextcloud..."
cd "${nextcloudFileDir}"
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --on'
#sudo -u "${webserverUser}" php occ maintenance:mode --on
cd ~
echo "Done"
echo

#
# Stop web server
#
echo "Stopping web server..."
service "${webserverServiceName}" stop
echo "Done"
echo

#
# Copy config.php to /mnt/NextcloudBackups
#
cp $nextcloudFileDir/config/config.php $backupMainDir/
echo "copy config.php"
echo "done"
echo

#
# Delete old Nextcloud direcories
#
echo "Deleting old Nextcloud file directory..."
rm -r "${nextcloudFileDir}"
mkdir -p "${nextcloudFileDir}"
echo "Done"
echo

echo "Deleting old Nextcloud data directory..."
rm -r "${nextcloudDataDir}"
mkdir -p "${nextcloudDataDir}"
echo "Done"
echo

#
# Restore file and data directory
#
echo "Restoring Nextcloud file directory..."
tar -xpzf "${currentRestoreDir}/${fileNameBackupFileDir}" -C "${nextcloudFileDir}"
echo "tar -xpzf "${currentRestoreDir}/${fileNameBackupFileDir}" -C ${nextcloudFileDir}"
#echo "rsync -Aax "${currentRestoreDir}/nextcloud/" ${nextcloudFileDir}"
#rsync -Aax "${currentRestoreDir}/nextcloud/" ${nextcloudFileDir}
echo "Done"
echo

echo "Restoring Nextcloud data directory..."
tar -xpzf "${currentRestoreDir}/${fileNameBackupDataDir}" -C "${nextcloudDataDir}"
echo "tar -xpzf "${currentRestoreDir}/${fileNameBackupDataDir}" -C ${nextcloudDataDir}"
#echo "rsync -Aax "${currentRestoreDir}/files/" ${nextcloudDataDir}"
#rsync -Aax ${currentRestoreDir}/files/ ${nextcloudDataDir}
echo "Done"
echo

#
# Restore database
#
echo "Dropping old Nextcloud DB..."
mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "DROP DATABASE ${nextcloudDatabase}"
echo "Done"
echo

echo "Creating new DB for Nextcloud..."
mysql -h localhost -u "${dbUser}" -p"${dbPassword}" -e "CREATE DATABASE ${nextcloudDatabase}"
echo "Done"
echo

echo "Restoring backup DB..."
mysql -h localhost -u "${dbUser}" -p"${dbPassword}" "${nextcloudDatabase}" < "${currentRestoreDir}/${fileNameBackupDb}"
echo "Done"
echo

#
# Start web server
#
echo "Starting web server..."
service "${webserverServiceName}" start
echo "Done"
echo

#
# Set directory permissions
#
echo "Setting directory permissions..."
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudFileDir}"
chown -R "${webserverUser}":"${webserverUser}" "${nextcloudDataDir}"
echo "Done"
echo

#
# Change the Database user and password back to the original not the backup
# Doesn't work yet- to be used if backup you restore has a different database dbuser and dbpassword
#
#sed -i '' "s/'dbuser' => [^[:space:]]*/'dbuser' => '${dbUser}'/" /usr/local/www/nextcloud/config/config.php
#sed -i '' "s/'dbpassword' => [^[:space:]]*/'dbpassword' => '${dbPassword}'/" /usr/local/www/nextcloud/config/config.php
#su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set dbuser --value="${dbUser}"'
#su -m www -c 'php /usr/local/www/nextcloud/occ config:system:set dbpassword --value="${dbPassword}"'

#echo "changed the Database user and password"

#
# Copy config.php back to original location
#
cp $backupMainDir/config.php "${nextcloudFileDir}/config/"
rm $backupMainDir/config.php
echo "replace with original config.php"
echo "done"
echo

#
# Disbale maintenance mode
#
echo "Switching off maintenance mode..."
cd "${nextcloudFileDir}"
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --off'
#sudo -u "${webserverUser}" php occ maintenance:mode --off
echo "Done"
echo


#su -m www -c 'php /usr/local/www/nextcloud/occ encryption:disable'

#
# Update the system data-fingerprint (see https://docs.nextcloud.com/server/13/admin_manual/configuration_server/occ_command.html#maintenance-commands-label)
#
echo "Updating the system data-fingerprint..."
cd "${nextcloudFileDir}"
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:data-fingerprint'
#sudo -u "${webserverUser}" php occ maintenance:data-fingerprint
echo "Done"
echo

#
# Disable 2 factor authentication and repair DB to fix and restore all shares
#
su -m www -c 'php /usr/local/www/nextcloud/occ twofactor:disable admin'
su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:repair'


#
# Disbale maintenance mode
#
#echo "Switching off maintenance mode..."
#cd "${nextcloudFileDir}"
#su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --off'
#sudo -u "${webserverUser}" php occ maintenance:mode --off
#echo "Done"
echo

#
# Reset nextcloud admin password
#
echo "reset admin password"
su -m www -c 'php /usr/local/www/nextcloud/occ user:resetpassword admin'
echo "su -m www -c 'php /usr/local/www/nextcloud/occ user:resetpassword admin'"
echo

#echo "If you receive errors with the last 2 commands you have to edit the config.php dbuser and dbpassword and run the last 2 commands manually"
#echo "su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:data-fingerprint'"
#echo "su -m www -c 'php /usr/local/www/nextcloud/occ maintenance:mode --off'"
echo
echo "DONE!"
echo "Backup ${restore} successfully restored."
exit 1
else
  echo "Must enter '(B)ackup' to backup Nextcloud or '(R)estore' to restore Nextcloud: "
fi

