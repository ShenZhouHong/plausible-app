#!/usr/bin/env bash
#
# Bash helper script for loading data onto clickhouse from backups located in
# /app/data/clickhouse/backups to the ephemeral runtime at /run/clickhouse/
# This script is managed as a process by Supervisord, which always ensures
# that it is started after Clickhouse, but before Plausible, and vice versa.

# Something is wrong with this program, supervisord cannot stop it. Currently
# We do not use it. I added this exit here so that we do not accidentally run
# this script under any circumstances:

exit 0 # Do not run this script, it does not work properly.

set -eEu -o pipefail

CLICKHOUSE_RESTORE_SCRIPT="/app/code/clickhouse-restore.sh"
CLICKHOUSE_BACKUP_SCRIPT="/app/code/clickhouse-backup.sh"

# Check if the restore script exists
if [ ! -x "$CLICKHOUSE_RESTORE_SCRIPT" ]; then
    echo "=> Error: The clickhouse-restore.sh script is missing or not executable."
    exit 1
fi

# Check if the backup script exists
if [ ! -x "$CLICKHOUSE_BACKUP_SCRIPT" ]; then
    echo "=> Error: The clickhouse-backup.sh script is missing or not executable."
    exit 1
fi

# Load clickhouse data from backup upon startup
function handle_startup {
    echo "=> Restoring clickhouse data from /app/data/clickhouse/backups upon startup"
    /app/code/clickhouse-restore.sh
}

# Backup clickhouse data from /run/clickhouse upon shutdown
function handle_shutdown {
    echo "=> Backing up clickhouse data from /run/clickhouse upon shutdown"
    /app/code/clickhouse-backup.sh
    exit 0
}

# Set up traps to call handle_shutdown on SIGTERM and SIGINT
trap 'handle_shutdown' SIGTERM
trap 'handle_shutdown' SIGINT

# Call the startup function
handle_startup

# After handling startup, we will simply wait indefinitely until SIGTERM
sleep infinity