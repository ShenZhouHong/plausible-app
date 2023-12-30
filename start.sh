#!/usr/bin/env bash
set -eEu -o pipefail

echo "=> Creating directories and files (if they do not already exist)"
# See these paths defined in clickhouse-config.xml
mkdir -p /app/data/clickhouse \
    /app/data/clickhouse/user_files \
    /app/data/clickhouse/user_scripts \
    /app/data/clickhouse/user_defined \
    /app/data/clickhouse/access \
    /app/data/clickhouse/format_schemas 
mkdir -p /run/clickhouse

# Plausible requires a PERSISTENT_CACHE_DIR and STORAGE_DIR. These are undocumented
# environment variables used to cache the MaxMind GeoIP Database, and for tzdata. See:
# https://github.com/plausible/analytics/blob/af6b578dc5dce94ec0bac6ab31f4be5bd8007ac3/config/runtime.exs#L232
# https://github.com/plausible/analytics/pull/1096
mkdir -p /app/data/plausible
mkdir -p /run/plausible/cache_dir \
    /run/plausible/storage_dir

# This is the default run location for Supervisord, the process manager
mkdir -p /run/supervisord/

# Ensure that data directory is owned by 'cloudron' user, and clickhouse by 'clickhouse' user
echo "=> Changing permissions"
chown -R cloudron:cloudron /app/data
chown -R cloudron:cloudron /run/plausible
chown -R clickhouse:cloudron /app/data/clickhouse
chown -R clickhouse:cloudron /run/clickhouse
# This is the default log location for Supervisord, the process manager
chown -R cloudron:cloudron /run/supervisord/

# Initialization code that will run only once upon installation
if [ ! -e /app/data/secrets.env ]; then
    echo "=> Creating initial templates on first run"
	cp /app/code/secrets.env.template /app/data/secrets.env
    cp /app/code/plausible-config.env.template /app/data/plausible-config.env
    cp /app/code/clickhouse-config.xml.template /app/data/clickhouse-config.xml
    cp /app/code/clickhouse-client.xml.template /app/data/clickhouse-client.xml
    cp /app/code/supervisord.conf.template /app/data/supervisord.conf

    echo "=> Provisioning secret keys on first run"
    # Secrets for Plausible
    sed -i "s/SECRET_KEY_BASE=/SECRET_KEY_BASE=$(openssl rand -hex 64)/" /app/data/secrets.env
    sed -i "s|TOTP_VAULT_KEY=|TOTP_VAULT_KEY=$(openssl rand -base64 32)|" /app/data/secrets.env
    
    # Secrets for Clickhouse Server and Client
    # Create password; create sha256 hash and then remove the '-' character and strip whitespace.
    CLICKHOUSE_DB_PASSWORD=$(openssl rand -hex 32)
    CLICKHOUSE_DB_PASSWORD_HASH=$(echo -n "$CLICKHOUSE_DB_PASSWORD" | sha256sum | tr -d '-' | xargs)
    sed -i "s/CLICKHOUSE_DB_PASSWORD=/CLICKHOUSE_DB_PASSWORD=${CLICKHOUSE_DB_PASSWORD}/" /app/data/secrets.env
    sed -i "s/CLICKHOUSE_DB_PASSWORD/${CLICKHOUSE_DB_PASSWORD}/" /app/data/plausible-config.env
    sed -i "s/PASSWORD_HASH_TEMPLATE/${CLICKHOUSE_DB_PASSWORD_HASH}/" /app/data/clickhouse-config.xml
    sed -i "s/PASSWORD_TEMPLATE/${CLICKHOUSE_DB_PASSWORD}/" /app/data/clickhouse-client.xml

    # Secrets for 'cloudron_supervisord' account on Supervisord [unix_http_server]
    SUPERVISORD_PASSWORD=$(openssl rand -hex 32)
    sed -i "s/SUPERVISORD_PASSWORD=/SUPERVISORD_PASSWORD=${SUPERVISORD_PASSWORD}/g" /app/data/secrets.env
    sed -i "s/PASSWORD_TEMPLATE/${SUPERVISORD_PASSWORD}/g" /app/data/supervisord.conf

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
exec supervisord --configuration=/app/data/supervisord.conf --nodaemon

