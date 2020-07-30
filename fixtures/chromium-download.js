const cp = require('child_process');

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

    instance.on('close', () => {
      instance.stdout.removeListener('data', handleStdout);
      instance.stderr.removeListener('data', handleStderr);

      if (!didResolve) {
        didResolve = true;
        resolve();
      }
    });

    instance.on('error', (error) => {
      reject(error);
    });
  });
}

async function runWithRetry(fn, { currentRetry = 0, delay = 1000, maxRetries = 3 } = {}) {
  try {
    return await fn();
  } catch (error) {
    if (currentRetry < maxRetries) {
      await new Promise((resolve) => {
        setTimeout(resolve, Math.pow(delay, currentRetry + 1));
      });

      return runWithRetry(fn, {
        currentRetry: currentRetry + 1,
        delay,
        maxRetries,
      });
    }

    throw error;
  }
}

void runWithRetry(downloadChromium);
