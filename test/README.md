# End-to-End Application Lifecycle Tests for Plausible

**Note:** Right now these tests are not implemented.

This directory contains the end-to-end (e2e) application lifecycle tests for the Plausible Analytics Cloudron app package. The tests include: 

* Creating a new Cloudron installation
* Backup up an existing installation and restoring from backup
* Moving to new location (i.e. subdomain)
* Testing the uninstallation process.

These tests use the mocha.js testing framework and the Selenium webdriver. They can be run via:

```bash
cd plausible-app/test

npm install
USERNAME=<cloudron username> PASSWORD=<cloudron password> mocha test.js

```