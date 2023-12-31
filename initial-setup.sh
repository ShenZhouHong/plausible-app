#!/usr/bin/env bash
#
# Initial setup code for Cloudron's Plausible Analytics app package. This is run
# only once when the application is first installed. The script takes care of one-time
# setup tasks, such as generating secrets, templating over configuration files, and
# Plausible's initial database setup. This script is called by /app/code/start.sh.
# It should never be run by the user directly once setup is completed.

set -eEu -o pipefail

# A final safety-check, in case the user runs the script accidentally post installation.
if [ -f /app/data/.initialized ]; then
    echo "=> Error! Your Plausible Analytics installation is already initialized"
    echo "Do not run this script as a user, you may break your installation!"
    exit 1
fi

echo "=> Creating initial templates on first run"
cp /app/code/secrets.env.template /app/data/secrets.env
cp /app/code/plausible-config.env.template /app/data/plausible-config.env
cp /app/code/clickhouse-config.xml.template /app/data/clickhouse-config.xml
cp /app/code/clickhouse-client.xml.template /app/data/clickhouse-client.xml
cp /app/code/supervisord.conf.template /app/data/supervisord.conf

echo "=> Provisioning secret keys for Plausible"
SECRET_KEY_BASE=$(openssl rand -hex 64)
TOPT_VAULT_KEY=$(openssl rand -base64 32)
sed -i "s|SECRET_KEY_BASE=|SECRET_KEY_BASE=${SECRET_KEY_BASE}|" /app/data/secrets.env
sed -i "s|TOTP_VAULT_KEY=|TOTP_VAULT_KEY=${TOPT_VAULT_KEY}|" /app/data/secrets.env

echo "=> Provisioning secret keys for Clickhouse database"
# Create password; create sha256 hash and then remove the '-' character and strip whitespace.
CLICKHOUSE_DB_PASSWORD=$(openssl rand -hex 32)
CLICKHOUSE_DB_PASSWORD_HASH=$(echo -n "$CLICKHOUSE_DB_PASSWORD" | sha256sum | tr -d '-' | xargs)
sed -i "s/CLICKHOUSE_DB_PASSWORD=/CLICKHOUSE_DB_PASSWORD=${CLICKHOUSE_DB_PASSWORD}/" /app/data/secrets.env
sed -i "s/CLICKHOUSE_DB_PASSWORD/${CLICKHOUSE_DB_PASSWORD}/" /app/data/plausible-config.env
sed -i "s/PASSWORD_HASH_TEMPLATE/${CLICKHOUSE_DB_PASSWORD_HASH}/" /app/data/clickhouse-config.xml
sed -i "s/PASSWORD_TEMPLATE/${CLICKHOUSE_DB_PASSWORD}/" /app/data/clickhouse-client.xml

echo "=> Provisioning secret keys for Supervisord"
# Secrets for 'cloudron_supervisord' account on Supervisord [unix_http_server]
SUPERVISORD_PASSWORD=$(openssl rand -hex 32)
sed -i "s/SUPERVISORD_PASSWORD=/SUPERVISORD_PASSWORD=${SUPERVISORD_PASSWORD}/g" /app/data/secrets.env
sed -i "s/PASSWORD_TEMPLATE/${SUPERVISORD_PASSWORD}/g" /app/data/supervisord.conf

echo "=> Initializing Plausible's databases on first run"    
# Temporarily start the clickhouse DBMS for migrations
sudo --user 'clickhouse' \
    /usr/bin/clickhouse-server \
        --config-file /app/data/clickhouse-config.xml \
        --pid-file /run/clickhouse/clickhouse-server.pid \
        --daemon
sleep 5 # Give clickhouse ample time to startup.

# Source the environment variables. These will become undefined once we are out of the if/fi block
source /app/data/secrets.env
source /app/data/plausible-config.env

# The migrate.sh script will exit with a non-zero exit code which we can safely ignore
/app/code/plausible/migrate.sh > "/run/plausible/migrations.log" 2>&1 || true

# Perform first backup of clickhouse database. This will be the base backup needed incremental backups
echo "=> Performing first backup of Clickhouse database"    
/app/code/clickhouse-backup.sh > "/run/clickhouse/backups.log" 2>&1

# Kill clickhouse
kill -TERM $(< /run/clickhouse/clickhouse-server.pid)
rm -f /run/clickhouse/clickhouse-server.pid
