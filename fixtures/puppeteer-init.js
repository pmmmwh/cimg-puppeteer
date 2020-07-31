const puppeteer = require('puppeteer');

process.on('unhandledRejection', (reason) => {
  throw reason;
});

async function puppeteerInit() {
  const browser = await puppeteer.launch({
    headless: true,
  });
  await browser.close();
}

void puppeteerInit();
