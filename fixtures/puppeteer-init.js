const puppeteer = require('puppeteer');
require('./commons');

async function puppeteerInit() {
  const browser = await puppeteer.launch({
    headless: true,
  });
  await browser.close();
}

void puppeteerInit();
