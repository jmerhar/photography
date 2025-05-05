#!/bin/bash
LOG=/var/log/photo-backup.log
SRC1=/Volumes/PhotoStore
SRC2=/Volumes/MorePhotos
TEMP=/tmp

HOST=aurora
ssh -q "${HOST}-local" exit && HOST="${HOST}-local"
DEST="$HOST:/mnt/storage/photos"

run () {
    "$@" | tee -a "$LOG"
}

remove () {
    run echo "Deleting $2 files from $1"
    run find "$1" -name "$2" -delete -print
}

clean () {
    remove "$1" '.DS_Store'
    remove "$1" '*_original'
    run dot_clean -v "$1"
}

backup () {
    local src=$1
    local exclude_src=$2

    run echo "Generating protection rules for $exclude_src"
    FILTER="$TEMP/filter.rules"
    # Create filter rules to protect files from the other source
    find "$exclude_src" -mindepth 1 | while IFS= read -r path; do
        relative_path="${path#$exclude_src/}"
        echo "P /$relative_path"  # Protect this path from deletion
    done > "$FILTER"

    run echo "Backing up $src to $HOST"
    run rsync -aHv --progress --exclude '.*' --filter="merge $FILTER" --delete "$src/" "$DEST"

    rm -f "$FILTER"
}

run echo "BEGIN $(date)"
clean "$SRC1"
clean "$SRC2"
backup "$SRC1" "$SRC2"  # Backup SRC1, protect SRC2 files
backup "$SRC2" "$SRC1"  # Backup SRC2, protect SRC1 files
run echo "END $(date)"