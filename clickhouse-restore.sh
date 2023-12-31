#!/usr/bin/env bash
#
# Bash script for performing restores of the ClickHouse database
# using clickhouse-client.
#
# The script checks for the existence and executability of clickhouse-client,
# as well as the presence of the backup directory. If conditions are met, it
# generates a backup query for the plausible_events_db database

set -eEu -o pipefail

backups_path="/app/data/clickhouse/backups"

# Check if clickhouse-client is installed
if ! command -v clickhouse-client &> /dev/null; then 
    echo "=> Unable to perform restore of clickhouse database"
    echo "   The clickhouse-client executable does not exist."
    exit 1
fi

# Check if backup path is accessible
if [ ! -d "$backups_path" ]; then
    echo "=> Unable to perform restore of clickhouse database."
    echo "${backups_path} does not exist"
    exit 1
fi

echo "=> Restoring clickhouse database with clickhouse-client"

# Retrieve a count of backups
counter=$(find "${backups_path}" -type f -name '*.zip' | wc --lines)

# Backup names are zero-indexed
latest_backup_name="plausible_events_db-$((counter - 1)).zip"

# Template query
query_str="DROP DATABASE IF EXISTS plausible_events_db; RESTORE DATABASE plausible_events_db FROM Disk('backups', '${latest_backup_name}');"
echo "${query_str}"

# Run the restore
/usr/bin/clickhouse-client \
    --config-file /app/data/clickhouse-client.xml \
    --multiquery "${query_str}"