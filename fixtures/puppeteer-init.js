const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
  });
  await browser.close();
})().catch(e => {
  throw e;
});
