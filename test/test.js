#!/usr/bin/env node

/* jshint esversion: 8 */
/* global describe */
/* global before */
/* global after */
/* global it */
/* global xit */

'use strict';

require('chromedriver');

const execSync = require('child_process').execSync,
    expect = require('expect.js'),
    fs = require('fs'),
    path = require('path'),
    request = require('request'),
    manifest = require('../CloudronManifest.json'),
    { Builder, By, until } = require('selenium-webdriver'),
    { Options } = require('selenium-webdriver/chrome');

if (!process.env.USERNAME || !process.env.PASSWORD) {
    console.log('USERNAME and PASSWORD env vars need to be set');
    process.exit(1);
}

describe('Application life cycle test', function () {
    this.timeout(0);

    // Test environment specific constants
    const EXEC_ARGS = { cwd: path.resolve(__dirname, '..'), stdio: 'inherit' };
    const LOCATION = 'test';
    const TEST_TIMEOUT = 30000;
    const username = process.env.USERNAME;
    const password = process.env.PASSWORD;

    // Plausible-specific Test Constants
    // TODO

    // Clickhouse-specific Test Constants 
    // TODO

    let app, browser;

    before(function () {
        browser = new Builder().forBrowser('chrome').setChromeOptions(new Options().windowSize({ width: 1280, height: 1024 })).build();
    });

    after(function () {
        browser.quit();
    });

    function getAppInfo() {
        /*
            Retrieves important Cloudron application details and stores them inside the app variable.
            Used to define variables such as app.fqdn which are used in the selenium test harness.
        */
        var inspect = JSON.parse(execSync('cloudron inspect'));
        app = inspect.apps.filter(function (a) { return a.location.indexOf(LOCATION) === 0; })[0];
        expect(app).to.be.an('object');
    }

    async function waitForElement(elem) {
        /*
            Helper function that forces the Selenium browser to wait for the availability of an
            element before continuing. Often used in between steps, since Selenium by default performs
            actions so fast it can out-run the web UI's ability to load DOM elements.
        */
        await browser.wait(until.elementLocated(elem), TEST_TIMEOUT);
        await browser.wait(until.elementIsVisible(browser.findElement(elem)), TEST_TIMEOUT);
    }

    async function bootstrap() {
        /*
            Bootstrap function performs first-time setup for Plausible.
        */
        await browser.get(`https://${app.fqdn}/register`);
        // TODO
    }

    async function login() {
        /*
            Logs in to Plausible.
        */
        await browser.get(`https://${app.fqdn}/login`);
        // TODO 
    }

    async function logout() {
        /*
            Logs out of Plausible.
        */
        await browser.get(`https://${app.fqdn}/`);
        // TODO
    }

    // Test app installation
    xit('build app', function () { execSync('cloudron build', EXEC_ARGS); });
    it('install app', function () { execSync(`cloudron install --location ${LOCATION}`, EXEC_ARGS); });
    it('can get app information', getAppInfo);
    // it('can set server password and create account', bootstrap); // This also logs the user in.
    // it('can logout', logout);

    // Test app restart
    it('can restart app', function () { execSync(`cloudron restart --app ${app.id}`, EXEC_ARGS); });
    // it('can login', login);
    // it('can logout', logout);

    // Test app backup and restore
    it('backup app', function () { execSync(`cloudron backup create --app ${app.id}`); });
    it('restore app', function () {
        const backups = JSON.parse(execSync(`cloudron backup list --raw --app ${app.id}`));
        execSync('cloudron uninstall --app ' + app.id, EXEC_ARGS);
        execSync('cloudron install --location ' + LOCATION, EXEC_ARGS);
        getAppInfo();
        execSync(`cloudron restore --backup ${backups[0].id} --app ${app.id}`, EXEC_ARGS);
    });
    // it('can login', login);
    // it('can logout', logout);

    // Test move app to different location
    it('move to different location', async function () {
        browser.manage().deleteAllCookies();
        await browser.get('about:blank'); // ensure we don't hit NXDOMAIN in the mean time

        execSync(`cloudron configure --app ${app.id} --location ${LOCATION}2`, EXEC_ARGS);
        getAppInfo();
    });
    // it('can login', login);
    // it('can logout', logout);

    // Test app update
    // TODO: Write install app for update test, once we have a real cloudron appstore ID. Will skip for now.\
    //
    // it('uninstall app', async function () {
    //     await browser.get('about:blank'); // ensure we don't hit NXDOMAIN in the mean time
    //     execSync(`cloudron uninstall --app ${app.id}`, EXEC_ARGS);
    // });
    // it('can install app for update', function () { execSync(`cloudron install --appstore-id TODO_APPSTORE_ID --location ${LOCATION}`, EXEC_ARGS); });
    // it('can get app information', getAppInfo);
    // it('can update', function () { execSync(`cloudron update --app ${LOCATION}`, EXEC_ARGS); });
    // it('can get app information', getAppInfo);
    // it('can login', login);
    // it('can logout', logout);

    // Final uninstall and cleanup
    it('uninstall app', async function () {
        await browser.get('about:blank'); // ensure we don't hit NXDOMAIN in the mean time
        execSync(`cloudron uninstall --app ${app.id}`, EXEC_ARGS);
    });
});
