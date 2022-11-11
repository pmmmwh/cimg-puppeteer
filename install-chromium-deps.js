const cp = require('child_process');
const util = require('util');

const KNOWN_DEPENDENCIES = [
  'ca-certificates',
  'fonts-freefont-ttf',
  'fonts-ipafont-gothic',
  'fonts-kacst',
  'fonts-khmeros',
  'fonts-liberation',
  'fonts-thai-tlwg',
  'fonts-wqy-zenhei',
  'libasound2',
  'libatk-bridge2.0-0',
  'libatk1.0-0',
  'libatspi2.0-0',
  'libc6',
  'libcairo2',
  'libcups2',
  'libcurl3-gnutls',
  'libdbus-1-3',
  'libdrm2',
  'libexpat1',
  'libgbm1',
  'libglib2.0-0',
  'libgtk-3-0',
  'libnspr4',
  'libnss3',
  'libpango-1.0-0',
  'libwayland-client0',
  'libx11-6',
  'libx11-xcb1',
  'libxcb1',
  'libxcomposite1',
  'libxdamage1',
  'libxext6',
  'libxfixes3',
  'libxkbcommon0',
  'libxrandr2',
  'libxss1',
  'libxtst6',
  'wget',
  'xdg-utils',
];

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

  for (const dep of KNOWN_DEPENDENCIES) {
    if (!dependencies.includes(dep)) {
      dependencies.push(dep);
    }
  }

  dependencies.sort();

  console.log('Installing chromium dependencies ...');
  console.log(JSON.stringify(dependencies));

  await execFile('apt-get', ['install', '--no-install-recommends', '-y', ...dependencies]);
}

void installChromiumDeps();
