#!/usr/bin/env bash

fail() {
    printf '%s\n' $* >&2
    exit 1
}

# Test for removal of the setup script
if [[ -f "/tmp/setup-headless-chromium.js" ]]; then
    fail "Setup script was not removed!"
fi

# Test for successful puppeteer installation
yarn add puppeteer

# Test for successful puppeteer execution
node ./puppeteer.fixture.js
