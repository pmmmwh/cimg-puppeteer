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

  dependencies.sort();

  console.log('Installing chromium dependencies ...');
  console.log(JSON.stringify(dependencies, null, 2));

  await execFile('apt-get', ['install', '-y', ...dependencies]);
}

void installChromiumDeps();
