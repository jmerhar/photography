#!/bin/bash
LOG=/var/log/photo-backup.log
SRC1=/Volumes/PhotoStore
SRC2=/Volumes/MorePhotos
TEMP=/tmp

HOST=`aurora`
ssh -q $HOST-local exit
[[ $? -eq 0 ]] && HOST=$HOST-local
DEST="$HOST:/mnt/storage/photos"

run () {
    "$@" | tee -a $LOG
}

remove () {
    run echo "Deleting $2 files from $1"
    run find $1 -name "$2" -delete -print    
}

clean () {
    remove "$1" '.DS_Store'
    remove "$1" '*_original'
    run dot_clean -v $1
}

backup () {
    run echo Generating an exclusion list for $2
    EXCL="$TEMP/exclusion-list.csv"
    find $2/* -print0 | xargs -0 realpath --relative-to=$2 > $EXCL

    run echo Backing up $1 to $HOST
    run rsync -aHv --progress --exclude '.*' --exclude-from=$EXCL --delete "$1/" "$DEST"

    rm $EXCL
}

run echo BEGIN `date`
clean $SRC1
clean $SRC2
backup $SRC1 $SRC2
backup $SRC2 $SRC1
run echo END `date`
