#!/usr/bin/env bash
set -eEu -o pipefail

echo "=> Creating directories and files (if they do not already exist)"
# Creating paths for Clickhouse
# See these paths defined in clickhouse-config.xml
mkdir -p \
    /app/data/clickhouse \
    /app/data/clickhouse/access \
    /app/data/clickhouse/backups \
    /app/data/clickhouse/format_schemas \
    /app/data/clickhouse/user_files \
    /app/data/clickhouse/user_scripts \
    /app/data/clickhouse/user_defined
mkdir -p /run/clickhouse

# Creating paths for Plausible
# Plausible requires PERSISTENT_CACHE_DIR and STORAGE_DIR. See plausible-config.env for details
mkdir -p \
    /app/data/plausible \
    /app/data/plausible/cache_dir \
    /app/data/plausible/storage_dir
mkdir -p /run/plausible

# Creating paths for supervisord
# This is the default run location for Supervisord, the process manager
mkdir -p /run/supervisord

# Ensure that data directory is owned by 'cloudron' user, and clickhouse by 'clickhouse' user
echo "=> Changing permissions"
chown -R cloudron:cloudron /app/data
chown -R clickhouse:cloudron /app/data/clickhouse
chown -R cloudron:cloudron /run/plausible
chown -R clickhouse:cloudron /run/clickhouse
chown -R cloudron:cloudron /run/supervisord/

# Initialization code that will run only once upon installation
if [ ! -f /app/data/.initialized ]; then
    echo "=> Initializing first-time installation"    
    /app/code/initial-setup.sh
    
    echo "=> First-time install initialization complete"
    echo 'true' > /app/data/.initialized
fi

# Load secrets and configuration options
source /app/data/secrets.env
source /app/data/plausible-config.env

# Here we need to run two processes. We will use supervisord. See:
# https://docs.docker.com/config/containers/multi-service_container/
# Exec will inherit the exported environment variables that we sourced above
# and supervisord will inherit those exported variables from exec.
# We won't use exec /usr/local/bin/gosu cloudron:cloudron [command] because
# Supervisord will take care of dropping privileges for us. See: supervisord.conf
echo "=> Starting Clickhouse Database and Plausible Server via Supervisord"
exec supervisord --configuration=/app/data/supervisord.conf --nodaemon

