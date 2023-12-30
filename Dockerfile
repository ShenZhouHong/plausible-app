FROM cloudron/base:4.2.0@sha256:46da2fffb36353ef714f97ae8e962bd2c212ca091108d768ba473078319a47f4

RUN mkdir -p /app/code/plausible /app/data

# Prerequisites
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    dirmngr \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Clickhouse, an open source high-performance DBMS
# https://clickhouse.com/docs/en/install
# Add GPG key for the Clickhouse apt repository
RUN GNUPGHOME=$(mktemp -d) gpg --no-default-keyring --keyring /usr/share/keyrings/clickhouse-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 8919F6BD2B48D754
RUN echo "deb [signed-by=/usr/share/keyrings/clickhouse-keyring.gpg] https://packages.clickhouse.com/deb stable main" | sudo tee /etc/apt/sources.list.d/clickhouse.list
# Cleanup Gnupg-related temporary files
RUN rm -rf "$GNUPGHOME"

# Prior to installation, map clickhouse directories to their Cloudron locations
# /var/log/clickhouse-server/ - Log directories
RUN mkdir -p /run/log/clickhouse-server \
    && ln -s /run/log/clickhouse-server /var/log/clickhouse-server
# /var/lib/clickhouse/        - Default Data Directory. Changed in clickhouse-config.xml
# /etc/clickhouse-server/     - Default Configurations. Changed in clickhouse-config.xml
# /var/run/clickhouse-server/ - Not Needed, Cloudron already maps this to /run/
# /etc/clickhouse-client/     - Not needed, will not be used in regular operation
# /etc/clickhouse-keeper/     - Not Needed, will not be used in regular operation

# Install Clickhouse
RUN apt-get update && apt-get install -y \
    clickhouse-client \
    clickhouse-server \
    && rm -rf /var/lib/apt/lists/*
# Note: Clickhouse will install successfully, but output the following warning:
# "Cannot set 'net_admin' or 'ipc_lock' or 'sys_nice' or 'net_bind_service' capability for clickhouse binary."
# These are optional features which requires a Docker container to be run with the --privileged flag.
# Clickhouse will run successfully without these features. See the following documentation for more info:
#   https://clickhouse.com/docs/knowledgebase/configure_cap_ipc_lock_and_cap_sys_nice_in_docker
#   https://docs.docker.com/engine/reference/run/#runtime-privilege-and-linux-capabilities

# The clickhouse-server binary requires itself to be run as the `clickhouse` user. Hence in order
# to simplify permissions compatibility, we will add it to the cloudron group:
RUN usermod -a -G cloudron clickhouse

# Download Pre-compiled Plausible Analytics Binary
WORKDIR /app/code/plausible
ARG VERSION=plausible-ubuntu-build-3
RUN curl -L https://github.com/ShenZhouHong/plausible-ubuntu-binaries/releases/download/${VERSION}/plausible-ubuntu-binary.tar.gz | tar -xz --strip-components 1 -f -

# Now it is time to copy all template configuration files from ./config/. These will be initialized 
# upon first installation via start.sh
WORKDIR /app/code
ADD --chown=cloudron ./configs/*.template /app/code/

# Custom scripts to Backup and Restore Clickhouse Database
ADD --chown=cloudron ./clickhouse-backup.sh ./clickhouse-restore.sh /app/code/

# Add start script. This contains setup and initialization code
ADD --chown=cloudron start.sh /app/code/

# Get ready for start
WORKDIR /app/data
EXPOSE 8000
CMD [ "/app/code/start.sh" ]