const cp = require('child_process');
const util = require('util');

const sudo = (command, args, options) => {
  return util.promisify(cp.execFile)('sudo', [command, ...args], options);
};

async function installChromiumDeps() {
  const { stdout: simulateStdout } = await sudo('apt-get', [
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

  await sudo('apt-get', ['install', '-y', ...dependencies]);
}

void installChromiumDeps();
