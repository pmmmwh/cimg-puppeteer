const { cp, fs } = require('./commons');
const path = require('path');

process.on('unhandledRejection', (reason) => {
  throw reason;
});

const chromiumInstallPath = path.join(__dirname, '..', 'node_modules/puppeteer/.local-chromium');

async function runWithRetry(
  fn,
  { backoff = 2, currentRetry = 0, delay = 100, maxRetries = 5 } = {}
) {
  try {
    return await fn();
  } catch (error) {
    if (currentRetry < maxRetries) {
      await new Promise((resolve) => {
        setTimeout(resolve, delay * Math.pow(backoff, currentRetry + 1));
      });

      console.log('Retrying...');
      return runWithRetry(fn, {
        backoff,
        currentRetry: currentRetry + 1,
        delay,
        maxRetries,
      });
    }

    throw error;
  }
}

async function rmdirRecursive(dirPath) {
  if (await fs.exists(dirPath)) {
    const files = await fs.readdir(dirPath);
    await Promise.all(
      files.map(async (file) => {
        const filePath = path.join(dirPath, file);
        const fileStats = await fs.lstat(filePath);
        if (fileStats.isDirectory()) {
          await rmdirRecursive(filePath);
        } else {
          await fs.unlink(filePath);
        }
      })
    );

    await fs.rmdir(dirPath);
  }
}

function downloadChromium() {
  return new Promise((resolve, reject) => {
    const instance = cp.spawn('node', [require.resolve('puppeteer/install')]);
    let didResolve = false;

    function handleStdout(data) {
      const message = data.toString();
      process.stdout.write(message);

      if (/^Chromium( \([0-9]{6}\))* downloaded to/.test(message)) {
        if (!didResolve) {
          didResolve = true;
          resolve(instance);
        }
      }
    }

    function handleStderr(data) {
      const message = data.toString();
      process.stderr.write(message);
    }

    instance.stdout.on('data', handleStdout);
    instance.stderr.on('data', handleStderr);

    instance.on('close', (code) => {
      instance.stdout.removeListener('data', handleStdout);
      instance.stderr.removeListener('data', handleStderr);

      if (code === 0) {
        if (!didResolve) {
          didResolve = true;
          resolve();
        }
      } else {
        void rmdirRecursive(chromiumInstallPath).then(() => {
          reject(new Error('Chromium download failed!'));
        });
      }
    });

    instance.on('error', (error) => {
      reject(error);
    });
  });
}

void runWithRetry(downloadChromium).then(async () => {
  // Node.js v14.0.0 have bugs related to stream closing,
  // which in turn breaks zip extraction of Puppeteer v3+.
  if (process.version === 'v14.0.0') {
    const { version: puppeteerVersion } = require('puppeteer/package.json');

    if (parseInt(puppeteerVersion, 10) > 2) {
      const { _preferredRevision: chromiumRevision } = require('puppeteer');

      // Clean the installation directory just to be safe
      await rmdirRecursive(path.join(chromiumInstallPath, `linux-${chromiumRevision}`));

      // Unzip Chromium into its correct place with posix unzip
      console.log('Node.js v14.0.0 - Unzipping from shell...');
      await cp.execFile('unzip', [
        '-o',
        '-q',
        '-d',
        path.join(path.join(chromiumInstallPath, `linux-${chromiumRevision}`)),
        path.join(chromiumInstallPath, 'chrome-linux.zip'),
      ]);

      // Delete the Chromium zip file
      await fs.unlink(path.join(chromiumInstallPath, 'chrome-linux.zip'));

      console.log('Node.js v14.0.0 - Chromium unzip success!');
    }
  }
});
