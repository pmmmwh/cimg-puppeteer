const cp = require('child_process');
const fs = require('fs');
const path = require('path');

process.on('unhandledRejection', (reason) => {
  throw reason;
});

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

      console.log('Retrying...')
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

function rmdirRecursive(dirPath) {
  if (fs.existsSync(dirPath)) {
    const files = fs.readdirSync(dirPath);
    files.forEach((file) => {
      const filePath = path.join(dirPath, file);
      const fileStats = fs.lstatSync(filePath);
      if (fileStats.isDirectory()) {
        rmdirRecursive(filePath);
      } else {
        fs.unlinkSync(filePath);
      }
    });

    fs.rmdirSync(dirPath);
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
        const installPath = path.join(__dirname, '..', 'node_modules/puppeteer/.local-chromium');
        rmdirRecursive(installPath);

        reject(new Error('Chromium download failed!'));
      }
    });

    instance.on('error', (error) => {
      reject(error);
    });
  });
}

void runWithRetry(downloadChromium);
