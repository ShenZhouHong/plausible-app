#!/usr/bin/env bash
#
# Bash script for performing backups of the ClickHouse database
# using clickhouse-client.
#
# The script checks for the existence and executability of clickhouse-client,
# as well as the presence of the backup directory. If conditions are met, it
# generates a backup query for the plausible_events_db database, creating a new
# backup file with an incremented counter.

set -eEu -o pipefail

# We disable incremental backups for now, since something weird is happening w/ them
incremental=false

backups_path="/app/data/clickhouse/backups"

# Check if clickhouse-client is installed
if ! command -v clickhouse-client &> /dev/null; then 
    echo "=> Unable to perform backup of clickhouse database"
    echo "   The clickhouse-client executable does not exist."
    exit 1
fi

# Check if backup path is accessible
if [ ! -d "$backups_path" ]; then
    echo "=> Unable to perform backup of clickhouse database."
    echo "${backups_path} does not exist"
    exit 1
fi

# Setup for incremental backups
counter=$(find "${backups_path}" -type f -name '*.zip' | wc --lines)

# Template the correct query string
if [ "$counter" -eq 0 ] || [ "$incremental" = false ]; then
    # Query for a full backup
    current_backup_name="plausible_events_db-0.zip"
    echo "=> Performing full backup: ${current_backup_name}"
    query_str="BACKUP DATABASE plausible_events_db TO Disk('backups', '${current_backup_name}')"
else
    # Query for incremental backup, using previous backup as base backup.
    current_backup_name="plausible_events_db-${counter}.zip"
    previous_backup_name="plausible_events_db-$((counter - 1)).zip"
    echo "=> Performing incremental backup: ${current_backup_name}"
    query_str="BACKUP DATABASE plausible_events_db TO Disk('backups', '${current_backup_name}') SETTINGS base_backup = Disk('backups', '${previous_backup_name}')"
fi
echo "${query_str}"

echo "=> Backing up clickhouse database with clickhouse-client"
# Run the backup
/usr/bin/clickhouse-client \
    --config-file /app/data/clickhouse-client.xml \
    --query "${query_str}" \