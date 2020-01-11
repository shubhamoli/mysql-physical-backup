#!/bin/sh


set -eu

# log messages for debugging later
log(msg) {
    NOW=`date '+%Y-%m-%d %H:%M:%S:%s'`
    echo $NOW: $msg >> $BACKUP_DIR/xtrabackup.log
}

full_backup() {
    # we need a fresh directory
    rm -rf $BASE_DIR/*

    if [ ! -d $BACKUP_DIR ] ; then
        mkdir -p $BACKUP_DIR
    fi

    touch $BACKUP_DIR/xtrabackup.log

    log "Initiating full backup..."
    xtrabackup  --user=$DB_USER \
                --password=$DB_PASS \
                --backup \
                --history \
                --compress \
                --slave-info \
                --compress-threads=2 \
                --target-dir=$BACKUP_DIR/FULL
    log "Full Backup done"

    log "Zipping the backup and transferring the backup to S3..."
    cd $BASE_DIR && tar -cf --no-auto-compress \
                            db-backup-$CURR_DATE.tar.gz \
                            db-backup-$CURR_DATE
    
    cd $BASE_DIR && aws s3 cp db-backup-$CURR_DATE.tar.gz \
                           s3://tripoto/database/db-backup-$CURR_DATE.tar.gz
    log "Backup Transferred!"
}

incremental_backup(){

    # Incremental backups need a full backup to start with
    # hence, if no full backup found then exit 
    if [ ! -d $BACKUP_DIR/FULL ] ; then
        echo "ERROR: Unable to find the FULL Backup. aborting....."
        exit -1
    fi

    # check if we have any inc. backup number
    if [ ! -f $BACKUP_DIR/last_incremental_number ]; then
        # if no file is present, assume #1
        NUMBER=1
        INC_BASE_DIR=$BACKUP_DIR/FULL
    else
        # else, +1 to number in file
        NUMBER=$(($(cat $BACKUP_DIR/last_incremental_number) + 1))
        INC_BASE_DIR=$BACKUP_DIR/inc$(($NUMBER - 1))
    fi

    log "Starting incremental backup #$NUMBER"
    xtrabackup  --user=$DB_USER \
                --password=$DB_PASS \
                --backup \
                --history \
                --slave-info \
                --incremental \
                --target-dir=$BACKUP_DIR/inc$NUMBER \
                --incremental-basedir=$INC_BASE_DIR 

    log "Incremental backup #$NUMBER done!"
    
    # updating incremental backup number in the file
    # so that next inc. backup should have correct numbering
    echo $NUMBER > $BACKUP_DIR/last_incremental_number
    
    log "Zipping and transferring incremental backup to S3"
    cd $BASE_DIR && tar -czf \
                        db-backup-$CURR_DATE-inc$NUMBER.tar.gz \
                        db-backup-$CURR_DATE/inc$NUMBER

    cd $BASE_DIR && aws s3 \ 
                        cp db-backup-$CURR_DATE-inc$NUMBER.tar.gz \
                        s3://tripotostaging/database/db-backup-$CURR_DATE-inc$NUMBER.tar.gz
    log "Backup transferred successfully!"
}


## Parameters
BASE_DIR=/opt/backups
CURR_DATE=$(date +\%Y-\%m-\%d)
BACKUP_DIR=$BASE_DIR/db-backup-$CURR_DATE
DATA_DIR=/var/lib/mysql/

if [ $# -eq 0 ]; then
    echo "Please pass options: full, incremental or restore"
    exit 1
fi

case $1 in
    "full")
        full_backup
    ;;
    "incremental")
        incremental_backup
    ;;
    *) 
        echo "invalid option"
    ;;
esac

