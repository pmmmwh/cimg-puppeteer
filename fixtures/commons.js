const cp = require('child_process');
const fs = require('fs');
const util = require('util');

process.on('unhandledRejection', (reason) => {
  throw reason;
});

module.exports = Object.freeze({
  cp: {
    execFile: util.promisify(cp.execFile),
    spawn: cp.spawn,
  },
  fs: {
    exists: util.promisify(fs.exists),
    lstat: util.promisify(fs.lstat),
    readdir: util.promisify(fs.readdir),
    rmdir: util.promisify(fs.rmdir),
    unlink: util.promisify(fs.unlink),
  },
});
