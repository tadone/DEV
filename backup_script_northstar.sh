#!/usr/bin/env bash

# Set the date format, filename and the directories where your backup files will be placed and which directory will be archived.
NOW=$(date +"%Y-%m-%d-%H%M")
SITENAME="com.northstarheatingandac"
FILE="$SITENAME-$NOW.tar"
BACKUP_DIR="$HOME/backups"
WWW_DIR="/var/www/html"
LOG_FILE="$HOME/backups/backup.log"
S3_BUCKET='s3://webvision-backups'

# MySQL database credentials
#DB_USER="northstar"
#DB_PASS="AuDTRCul4g6moLvn"
#DB_NAME="northstar"
#DB_FILE="$DB_NAME-$NOW.sql"

# Test for backup directory
if [[ ! -d  "$BACKUP_DIR" ]]; then
	mkdir "$BACKUP_DIR" || exit
	printf "Creating backup directory" >> $LOG_FILE
fi

# Create the archive and the MySQL dump
printf "\n $NOW --- Backing up $SITENAME ---" >> $LOG_FILE
printf "\n Backing up $WWW_DIR to $BACKUP_DIR" >> $LOG_FILE
# Archive website files
tar -cvf $BACKUP_DIR/$FILE -C /var/www/ html >/dev/null 2>&1

#printf "\n - Backing up MySQL database: $DB_NAME" >> $LOG_FILE
#mysqldump --user=$DB_USER --password=$DB_PASS --add-drop-table $DB_NAME > /tmp/$DB_FILE
#mysqldump -u$DB_USER -p$DB_PASS -$DB_NAME > $BACKUP_DIR/$DB_FILE

# Append the dump to the archive, remove the dump and compress the whole archive.
#tar --append --file=$BACKUP_DIR/$FILE -C /tmp/ $DB_FILE
#rm -v /tmp/$DB_FILE
gzip -9 $BACKUP_DIR/$FILE

# Upload backup to Amazon S3
printf "\n Uploading $FILE.gz to Amazon S3" >> $LOG_FILE
aws s3 cp $BACKUP_DIR/$FILE.gz $S3_BUCKET || exit

# Delete local backup file
printf "\n Deleting local file" >> $LOG_FILE
rm -v $BACKUP_DIR/$FILE.gz

printf "\n Backup Completed on: $(date +"%Y-%m-%d-%H%M")" >> $LOG_FILE
