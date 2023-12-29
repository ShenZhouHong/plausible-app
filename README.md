# Plausible Analytics Server Cloudron App

This repository contains the [Cloudron](cloudron.io) app package source for the [Plausible Analytics](https://github.com/plausible/analytics). [Plausible](https://plausible.io/) is an easy to use, lightweight (< 1 KB), open source and privacy-friendly alternative to Google Analytics. It doesn’t use cookies and is fully compliant with GDPR, CCPA and PECR.

## Overview

The Plausible analytics server depends upon two databases: PostgreSQL for user data, and Clickhouse for analytics data. PostgreSQL is already made available via Cloudron's native PostgreSQL addon. As a result, this app packages Clickhouse within itself for Plausible.

### Supervisord for Multi-process Docker Containerization

Cloudron app packages are Docker containers. Docker containers usually run one process per container. However, because Plausible depends upon Clickhouse, this Docker container must run both the Clickhouse database process, as well as the Plausible server process. In order to run multiple processes, we use Supervisord, a process management system. Supervisord is configured using the file at `./configs/supervisord.conf`.

The supervisor program takes care of daemonizing the Plausible and Clickhouse processes. As a result, supervisor must be run as root:

```bash
exec  supervisord --configuration=/app/code/supervisord.conf --nodaemon
```

Note that we do not use `exec /usr/local/bin/gosu cloudron:cloudron supervisord`, because supervisord takes care of changing users. These are defined in `./configs/supervisord.conf`.

### Configuration for Plausible and Clickhouse

Plausible is configured using environment variables that are exported, and then added to the shell environment using `source`. The template for Plausible-specific configuration settings are found at `./configs/plausible-config.env.template`, which are then populated by the `./start.sh` script during first startup. Secrets are likewise found in `./config/secrets.env.template` which are also generated upon first startup by `./start.sh`.

Clickhouse is configured using `./config/clickhouse-config.xml.template`. The clickhouse configuration re-maps the default paths to Cloudron's writeable directories.

Additional documentation on configuration files are [available here](./configs/README.md).

### Pre-Built Plausible Analytics Binaries

This Cloudron app package is unusual, because it depends upon an additional repository as a source of pre-built Plausible binaries for Ubuntu Linux. Plausible Analytics is a compiled Elixir/Erlang application, that cannot be run directly from the upstream source code. Plausible's authors does not currently provide pre-built binaries. As a result, the Dockerfile pulls pre-built binaries from the following unofficial repository.

* https://github.com/ShenZhouHong/plausible-ubuntu-binaries

## Installation

This custom Cloudron app has not yet been published to the official Cloudron app store. Hence in order to install it to your Cloudron instance, you must first build and deploy it to a private docker registry.

The easiest way to do this is to use Cloudron's pre-packaged [Private Docker Registry](https://docs.cloudron.io/apps/docker-registry/) app.

## Building
The app package can be built using the [Cloudron command line tooling](https://cloudron.io/references/cli.html).

### Build and Push to Private Docker Registry

```bash
cd plausible-app
cloudron build
cloudron install --image registry.example.com/plausible-app:${TAG}
```

## Testing

The end-to-end tests are located in the `test/` folder and require [nodejs](http://nodejs.org/). The tests include: creating a new Cloudron installation, backup up an existing installation, restoring from backup, moving to new location (i.e. subdomain), as well as testing the uninstallation process.

```bash
cd plausible-app/test

npm install
USERNAME=<cloudron username> PASSWORD=<cloudron password> mocha test.js
```

Additional documentation about the tests are available [at the following location](./test/README.md).

## To-Do List

Please note that this custom Cloudron application is currently in beta, and not yet suitable for production deployments. It is currently made available for testing purposes. Your data may be at risk.

 - [ ] Manage Clickhouse database backups using dump/restore
 - [ ] Write automated application lifecycle tests
 - [ ] Create Clickhouse addon to enable native Cloudron support
