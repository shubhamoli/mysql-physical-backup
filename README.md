# Mysql Physical Backup using XtraBackup

Author: Shubham Oli <oli.shubham@gmail.com>

---

Xtrabackup is a [hot (and physical) backup](https://docs.oracle.com/cd/E57185_01/EPMBK/ch01s02s01s01.html) utility be Percona community.

## Setting up backups

* Full Backup (every day at 5:00 A.M or time of least traffic)
`0 5 * * * scripts/backup.sh full`

* Incremental Backups (every 30 mins)
`*/30 * * * scripts/backup.sh incremental`

## Restore
`$ scripts/restore.sh <backup-name>`

## TODOs
[X] Write backup script for full backup

[X] Write backup script for incremental backup

[] Write restore script

## LICENSE 

MIT


