#!/usr/bin/env bash
set -eEu -o pipefail

echo "=> Creating directories and files (if they do not already exist)"
mkdir -p /app/data/clickhouse /app/data/clickhouse/user_files /app/data/plausible
mkdir -p /run/clickhouse
# These two are used for Plausible's lib/tzdata-1.1.1 libary, which requires read-write access
mkdir -p /run/tmp_downloads
touch /run/latest_remote_poll.txt
# This is the default run location for Supervisord, the process manager
mkdir -p /run/supervisord/

# Ensure that data directory is owned by 'cloudron' user, and clickhouse by 'clickhouse' user
echo "=> Changing permissions"
chown -R cloudron:cloudron /app/data
chown -R clickhouse:cloudron /app/data/clickhouse
chown -R clickhouse:cloudron /run/clickhouse
# These two are used for Plausible's lib/tzdata-1.1.1 libary, which requires read-write access
chown -R cloudron:cloudron /run/tmp_downloads
chown cloudron:cloudron /run/latest_remote_poll.txt
# This is the default log location for Supervisord, the process manager
chown -R cloudron:cloudron /run/supervisord/

# Initialization code that will run only once upon installation
if [ ! -e /app/data/secrets.env ]; then
    echo "=> Creating initial templates on first run"
	cp /app/code/secrets.env.template /app/data/secrets.env
    cp /app/code/plausible-config.env.template /app/data/plausible-config.env
    cp /app/code/clickhouse-config.xml.template /app/data/clickhouse-config.xml

    echo "=> Provisioning secret keys on first run"
    sed -i "s/SECRET_KEY_BASE=/SECRET_KEY_BASE=$(openssl rand -hex 64)/" /app/data/secrets.env
    # Here we use | (i.e. pipe) as our sed delimiter because base64 strings may contains / (i.e. slash)
    sed -i "s|TOTP_VAULT_KEY=|TOTP_VAULT_KEY=$(openssl rand -base64 32)|" /app/data/secrets.env
    CLICKHOUSE_DB_PASSWORD=$(openssl rand -hex 32)
    # Create sha256 hash, and then remove the '-' character and strip trailing whitespace.
    CLICKHOUSE_DB_PASSWORD_HASH=$(echo -n "$CLICKHOUSE_DB_PASSWORD" | sha256sum | tr -d '-' | xargs)
    sed -i "s/CLICKHOUSE_DB_PASSWORD=/CLICKHOUSE_DB_PASSWORD=${CLICKHOUSE_DB_PASSWORD}/" /app/data/secrets.env
    sed -i "s/CLICKHOUSE_DB_PASSWORD/${CLICKHOUSE_DB_PASSWORD}/" /app/data/plausible-config.env
    sed -i "s/<password_sha256_hex>/<password_sha256_hex>${CLICKHOUSE_DB_PASSWORD_HASH}/" /app/data/clickhouse-config.xml

    echo "=> Initializing Plausible's databases on first run"    
    # Temporarily start the clickhouse DBMS for migrations
    sudo --preserve-env -u 'clickhouse' /usr/bin/clickhouse-server --config-file /app/data/clickhouse-config.xml --pid-file /run/clickhouse/clickhouse-server.pid --daemon

    # Source the environment variables. These will become undefined once we are out of the if/fi block
    source /app/data/secrets.env
    source /app/data/plausible-config.env

    # migrate.sh will exit with a non-zero exit code which we can safely ignore
    /app/code/plausible/migrate.sh > "/run/migrations.log" 2>&1 || true

    # Kill clickhouse
    kill -TERM $(< /run/clickhouse/clickhouse-server.pid)
fi

# Load secrets and configuration options
source /app/data/secrets.env
source /app/data/plausible-config.env

# Here we need to run two processes. We will use supervisord. See:
# https://docs.docker.com/config/containers/multi-service_container/
# Exec will inherit the exported environment variables that we sourced above
# and supervisord will inherit those exported variables from exec.
echo "=> Starting Clickhouse Database and Plausible Server via Supervisord"
# Here we won't use exec /usr/local/bin/gosu cloudron:cloudron [command] because
# Supervisord will take care of dropping privileges for us. See: supervisord.conf
exec  supervisord --configuration=/app/code/supervisord.conf --nodaemon

