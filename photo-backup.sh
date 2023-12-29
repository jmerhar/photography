#!/bin/bash
LOG=/var/log/photo-backup.log
DIR=/Volumes/PhotoStore
CAF=/usr/bin/caffeinate
HOST=`aurora`
ssh -q $HOST-local exit
[[ $? -eq 0 ]] && HOST=$HOST-local
echo BEGIN `date` >> $LOG
echo 'Deleting .DS_Store files' >> $LOG
$CAF find $DIR -name '.DS_Store' >> $LOG
$CAF find $DIR -name '.DS_Store' -delete >> $LOG
echo 'Deleting *_original files' >> $LOG
$CAF find $DIR -name '*_original' >> $LOG
$CAF find $DIR -name '*_original' -delete >> $LOG
$CAF -s dot_clean -v $DIR >> $LOG 2>> $LOG
echo Backing up photos to $HOST >> $LOG
$CAF -s /usr/bin/rsync -aHv --progress --exclude '.*' --delete $DIR/ $HOST:/mnt/storage/photos >> $LOG
echo END `date` >> $LOG
