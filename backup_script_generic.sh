#!/bin/bash

# Set the date format, filename and the directories where your backup files will be placed and which directory will be archived.
NOW=$(date +"%Y-%m-%d-%H%M")
SITENAME="TestSite"
FILE="$SITENAME-$NOW.tar"
BACKUP_DIR="$HOME/backups"
WWW_DIR="/var/www/html"
LOG_FILE="$HOME/backups/backup.log"

# MySQL database credentials
DB_USER="choose_user"
DB_PASS="enter_password_here"
DB_NAME="enter_db_name_here"
DB_FILE="$DB_NAME-$NOW.sql"

# Test for backup directory
if [[ ! -d  "$BACKUP_DIR" ]]; then
	mkdir "$BACKUP_DIR"
	printf "Creating backup directory" >> $LOG_FILE
fi

# Create the archive and the MySQL dump
printf "\n $NOW --- Backing up $SITENAME ---" >> $LOG_FILE
printf "\n - Backing up $WWW_DIR to $BACKUP_DIR" >> $LOG_FILE
tar -cvf $BACKUP_DIR/$FILE -C /var/www/ html #Site files

printf "\n - Backing up MySQL database: $DB_NAME" >> $LOG_FILE
mysqldump --user=$DB_USER --password=$DB_PASS --add-drop-table $DB_NAME > /tmp/$DB_FILE
#mysqldump -u$DB_USER -p$DB_PASS -$DB_NAME > $BACKUP_DIR/$DB_FILE

# Append the dump to the archive, remove the dump and compress the whole archive.
tar --append --file=$BACKUP_DIR/$FILE -C /tmp/ $DB_FILE
rm -v /tmp/$DB_FILE
gzip -9 $BACKUP_DIR/$FILE
printf "\n - Backup file: $FILE.gz located in $BACKUP_DIR" >> $LOG_FILE
printf "\n $(date +"%Y-%m-%d-%H%M") --- Backup Completed ---" >> $LOG_FILE