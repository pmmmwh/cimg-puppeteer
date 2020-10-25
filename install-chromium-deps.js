const cp = require('child_process');
const util = require('util');

const execFile = util.promisify(cp.execFile);

async function installChromiumDeps() {
  const { stdout: simulateStdout } = await execFile('apt-get', [
    '--simulate',
    'install',
    'chromium-browser',
  ]);

  const dependencies = simulateStdout.split('\n').reduce((acc, cur) => {
    if (!/^Inst/.test(cur)) {
      return acc;
    }

    const [, dependency] = cur.split(' ');
    if (dependency.includes('chromium-browser')) {
      return acc;
    }

    return [...acc, dependency];
  }, []);

  // For some reason, some crucial dependencies might not install in certain versions of Ubuntu,
  // so we patch them in forcefully to make sure they exist in the final image.
  if (!dependencies.includes('libnss3')) {
    dependencies.push('libnss3');
  }
  if (!dependencies.includes('libx11-xcb1')) {
    dependencies.push('libx11-xcb1');
  }
  if (!dependencies.includes('libxss1')) {
    dependencies.push('libxss1');
  }

  dependencies.sort();

  console.log('Installing chromium dependencies ...');
  console.log(JSON.stringify(dependencies, null, 2));

  await execFile('apt-get', ['install', '-y', ...dependencies]);
}

void installChromiumDeps();
