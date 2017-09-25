#!/usr/bin/env bash

# Set the date format, filename and the directories where your backup files will be placed and which directory will be archived.
NOW=$(date +"%Y-%m-%d-%H%M")
start=`date +%s`
#SITENAME="com.northstarheatingandac"
#FILE="$SITENAME-$NOW.tar.gz"
BACKUP_DIR="$HOME/backups"
WWW_DIR="/var/www/html"
LOG_FILE="$HOME/backups/backup.log"
S3_BUCKET='s3://webvision-backups'

# List of sites
SITES=('com.midwestrenovationservices' \
'www.alloyweldinspection.com' \
'www.gowebvision.com' \
'www.marinerpalmsalf.com' \
'www.peacecentertours.com' \
'www.rusinrestoration.com' \
'www.secondcityconstruction.com' \
'www.shmcleaning.com' \
'www.zerubariel.com')

# Test for backup directory
if [[ ! -d  "$BACKUP_DIR" ]]; then
	mkdir "$BACKUP_DIR" || exit
	printf "Creating backup directory" >> $LOG_FILE
fi

# Create the archive and the MySQL dump
printf "\n Backup Started on: $NOW" >> $LOG_FILE
printf "\n Backing up $WWW_DIR to $BACKUP_DIR - $NOW" >> $LOG_FILE

# Archive website files
for site in ${SITES[@]}; do
	bak_name=$(echo "$site" | awk -F "." '{ print "com." $2 }')
	tar -czf $BACKUP_DIR/$bak_name-$NOW.tar.gz -C /var/www/html $site
	aws s3 cp $BACKUP_DIR/$bak_name-$NOW.tar.gz $S3_BUCKET || exit
	rm -v $BACKUP_DIR/$bak_name-$NOW.tar.gz
done

#printf "\n - Backing up MySQL database: $DB_NAME" >> $LOG_FILE
#mysqldump --user=$DB_USER --password=$DB_PASS --add-drop-table $DB_NAME > /tmp/$DB_FILE
#mysqldump -u$DB_USER -p$DB_PASS -$DB_NAME > $BACKUP_DIR/$DB_FILE

# Append the dump to the archive, remove the dump and compress the whole archive.
#tar --append --file=$BACKUP_DIR/$FILE -C /tmp/ $DB_FILE
#rm -v /tmp/$DB_FILE
#gzip -9 $BACKUP_DIR/$FILE

# Upload backup to Amazon S3
# printf "\n Uploading $FILE.gz to Amazon S3" >> $LOG_FILE
# aws s3 cp $BACKUP_DIR/$FILE.gz $S3_BUCKET || exit

# Delete local backup file
# printf "\n Deleting local file" >> $LOG_FILE
# rm -v $BACKUP_DIR/$FILE.gz
end=`date +%s`
runtime=$((end-start))
printf "\n Backup Completed. Runtime:$runtime sec. "
# printf "\n Backup Completed on: $(date +"%Y-%m-%d-%H%M")" >> $LOG_FILE
