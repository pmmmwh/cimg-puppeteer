const cp = require('child_process');

function downloadChromium() {
  return new Promise((resolve, reject) => {
    const instance = cp.spawn('node', [
      '--unhandled-rejections=strict',
      require.resolve('puppeteer/install'),
    ]);
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

    instance.on('close', (code, signal) => {
      instance.stdout.removeListener('data', handleStdout);
      instance.stderr.removeListener('data', handleStderr);

      if (code === 0) {
        if (!didResolve) {
          didResolve = true;
          resolve();
        }
      } else {
        reject(signal);
      }
    });

    instance.on('error', (error) => {
      reject(error);
    });
  });
}

async function runWithRetry(
  fn,
  { backoff = 2, currentRetry = 0, delay = 100, maxRetries = 3 } = {}
) {
  try {
    return await fn();
  } catch (error) {
    if (currentRetry < maxRetries) {
      await new Promise((resolve) => {
        setTimeout(resolve, delay * Math.pow(backoff, currentRetry + 1));
      });

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

void runWithRetry(downloadChromium);
