var exec = require('cordova/exec');

exports.installApp = function (name, error) {
    if (device.platform === 'Android')
        exec(null, error, 'AppManager', 'installApp', [name]);
};

exports.openApp = function (package, scheme, error) {
    if (device.platform === 'Android')
        exec(null, error, 'AppManager', 'openApp', [package]);
    else
        exec(null, error, 'AppManager', 'openApp', [scheme]);
};
               
exports.hasApp = function (package, scheme, success) {
    if (device.platform === 'Android')
        exec(success, null, 'AppManager', 'hasApp', [package]);
    else
        exec(success, null, 'AppManager', 'hasApp', [scheme]);
};

exports.exitApp = function () {
    exec(null, null, 'AppManager', 'exitApp', []);
};

exports.getPic = function (success) {
    exec(success, null, 'AppManager', 'getPic', []);
};

exports.checkProject = function (success) {
    exec(success, null, 'AppManager', 'checkProject', []);
};

exports.unzipProject = function (success) {
    exec(success, null, 'AppManager', 'unzipProject', []);
};

exports.md5Project = function (success) {
    exec(null, null, 'AppManager', 'md5Project', []);
};