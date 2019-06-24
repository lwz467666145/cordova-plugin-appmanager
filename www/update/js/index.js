(function (doc, win) {
    let docEl = doc.documentElement, resizeEvt = 'orientationchange' in win ? 'orientationchange' : 'resize',
        recalc = function () {
            let clientWidth = docEl.clientWidth;
            if (!clientWidth) return;
            docEl.style.fontSize = 20 * (clientWidth / 360) + "px";
        };

    if (!doc.addEventListener) return;
    win.addEventListener(resizeEvt, recalc, false);
    doc.addEventListener('DOMContentLoaded', recalc, false);
})(document, window);

let topSystemFlag = navigator.platform.toLocaleLowerCase().indexOf('win') < 0 && navigator.platform.toLocaleLowerCase().indexOf('macintel') < 0;

if (topSystemFlag) {
    let head = document.getElementsByTagName('head')[0];
    let cordova = document.createElement('script');
    cordova.type = 'text/javascript';
    cordova.src = '../cordova.js';
    head.appendChild(cordova);
    document.addEventListener('deviceready', () => {
        initPage();
    });
} else
    $(document).ready(() => {
        initPage();
    });

function initPage() {
    let updateConfig = {
        basePath: cordova.file.dataDirectory,
        serverPath: '',
        updatePath: '',
        appCode: '',
        appName: ''
    }, $background = $('[opt=background]'), $dialog = $('.dialog'),
        $inner = $('.inner'), $number = $('.number'), $tip = $('.tip'), date, timer;
    if (topSystemFlag) {
        navigator.appmanager.getPic(() => {
            $background.attr('src', updateConfig.basePath + 'updates/screen.png');
            $background.load(function () {
                checkUpdate();
            });
        });
    } else
        checkUpdate();

    function checkUpdate() {
        date = new Date();
        timer = setTimeout(function () {
            $inner.css({width: '100%'});
            $number.text('100%');
            $tip.text('初始化');
            $dialog.addClass('open');
            navigator.splashscreen.hide();
        }, 3000);
        $.ajax({
            url: updateConfig.updatePath,
            type: 'get',
            dataType: 'jsonp',
            jsonp: 'jsoncallback',
            timeout: 5000,
            data: {
                appCode: updateConfig.appCode,
                appPlatform: device.platform,
                appVersion: 'V' + navigator.appInfo.version
            },
            success: function (data) {
                if (data.resultFlag) {
                    if (data.object.isUse == "1") {
                        if (timer) {
                            clearTimeout(timer);
                            timer = null;
                        }
                        navigator.notification.confirm(
                            "检测到有新版本:" + data.object.appVersion + "\r\n" +
                            "大小:" + renderSize(data.object.appFileSize) + "\r\n" +
                            "本次更新内容:\r\n" + data.object.appVersionDescription,
                            function (btnIndex) {
                                if (btnIndex != 1) {
                                    if (data.object.isForced == "0") {
                                        date = new Date();
                                        checkProject();
                                    } else
                                        navigator.appmanager.exitApp();
                                } else
                                    update(data.object);
                            },
                            "更新提示",
                            "立即更新," + (data.object.isForced == "0" ? '稍后更新' : '退出')
                        );
                    } else
                        checkProject();
                } else
                    checkProject();
            },
            error: () => {
                console.log('timeout');
                checkProject();
            }
        });

        const renderSize = (value) => {
            if (null == value || value == '')
                return "0 Bytes";
            let unitArr = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"], size = parseFloat(value), index = 0;
            size = size / Math.pow(1024, (index = Math.floor(Math.log(size) / Math.log(1024))));
            size = parseInt((size * Math.pow(10, 2) + 0.5)) / Math.pow(10, 2);
            return size + unitArr[index];
        };

        const update = (data) => {
            if (device.platform == 'Android') {
                let progress = window.navigator.dialogsPlus.progressStart(
                    "下载提示",
                    "更新版本" + data.appVersion + "中，请稍后......"
                );
                let last = 0;
                window.resolveLocalFileSystemURL(cordova.file.externalDataDirectory, function (dirEntry) {
                    dirEntry.getDirectory('Download', {
                        create: true,
                        exclusive: false
                    }, function (childEntry) {
                        let fileTransfer = new FileTransfer();
                        fileTransfer.onprogress = function (progressEvent) {
                            if (progressEvent.lengthComputable) {
                                let percent = parseFloat((progressEvent.loaded / progressEvent.total).toFixed(2));
                                if (percent > last) {
                                    last = percent;
                                    progress.setValue(percent * 100);
                                }
                            }
                        };
                        fileTransfer.download(encodeURI($.trim(data.appDownloadAddress)), childEntry.nativeURL + data.appFileName, function (fileEntry) {
                            progress.hide(function(){}, function(){});
                            navigator.appmanager.installApp(data.appFileName);
                            navigator.appmanager.exitApp();
                        }, function (error) {
                            progress.hide(function(){}, function(){});
                            date = new Date();
                            checkProject();
                        });
                    }, function (e) {
                        progress.hide(function(){}, function(){});
                        date = new Date();
                        checkProject();
                    });
                });
            } else {
                window.location.href = "itms-services://?action=download-manifest&url=" + data.appDownloadAddress;
                navigator.appmanager.exitApp();
            }
        }
    }

    function checkProject() {
        if (timer)
            clearTimeout(timer);
        let now = new Date(), timeout = 0;
        timeout = 3000 - (now.getTime() - date.getTime());
        timeout = timeout < 0 ? 0 : timeout;
        timer = setTimeout(function () {
            if (!$dialog.hasClass('open')) {
                $dialog.addClass('open');
                navigator.splashscreen.hide();
            }
            $inner.css({width: '100%'});
            $number.text('100%');
            $tip.text('解压中');
        }, timeout);
        navigator.appmanager.checkProject((result) => {
            if (result == 'nothing')
                diffProject();
            else if (result == 'unzip')
                navigator.appmanager.unzipProject((result) => {
                    if (result == 'success')
                        diffProject();
                    else {
                        if (timer)
                            clearTimeout(timer);
                        navigator.notification.alert('文件解压失败，请重新下载应用', () => {
                            navigator.appmanager.exitApp();
                        }, '温馨提示', '确定');
                    }
                });
        });
    }

    function diffProject() {
        let serverJson = null, localJson = null, getJson = null, addFiles = [], delFiles = [], timer1 = null, count = 0;
        if (timer)
            clearTimeout(timer);
        let now = new Date(), timeout = 0;
        timeout = 3000 - (now.getTime() - date.getTime());
        timeout = timeout < 0 ? 0 : timeout;
        timer = setTimeout(function () {
            if (!$dialog.hasClass('open')) {
                $dialog.addClass('open');
                navigator.splashscreen.hide();
            }
            $inner.css({width: '100%'});
            $number.text('100%');
            $tip.text('更新中');
        }, timeout);
        timer1 = setTimeout(function () {
            getJson.abort();
        }, 5000);
        getJson = $.getJSON(updateConfig.serverPath + 'apps/' + updateConfig.appName + '.json', (json) => {
            if (!timer1)
                clearTimeout(timer1);
            serverJson = json;
            getLocalJson();
        }).error(function () {
            if (!timer1)
                clearTimeout(timer1);
            goHome();
        });

        const getLocalJson = () => {
            $.getJSON(updateConfig.basePath + 'updates/files.json', (json) => {
                localJson = json;
                diffFiles();
            }).error(function () {
                goHome();
            });
        };

        const diffFiles = () => {
            if (serverJson.count && localJson.count) {
                serverJson.files.forEach((serverFile) => {
                    let flag = false;
                    try {
                        localJson.files.forEach((localFile) => {
                            if (serverFile.filePath == localFile.filePath) {
                                flag = true;
                                if (serverFile.fileMd5 != localFile.fileMd5) {
                                    addFiles.push(serverFile);
                                    throw new Error('');
                                }
                            }
                        });
                    } catch (e) {}
                    if (!flag)
                        addFiles.push(serverFile);
                });
                localJson.files.forEach((localFile) => {
                    let flag = false;
                    try {
                        serverJson.files.forEach((serverFile) => {
                            if (localFile.filePath == serverFile.filePath) {
                                flag = true;
                                throw new Error('');
                            }
                        });
                    } catch (e) {}
                    if (!flag)
                        delFiles.push(localFile);
                });
                if (addFiles.length || delFiles.length) {
                    count = addFiles.length + delFiles.length;
                    openDir();
                } else
                    goHome();
            }
        };

        const openDir = () => {
            if (timer)
                clearTimeout(timer);
            let now = new Date(), timeout = 0;
            timeout = 3000 - (now.getTime() - date.getTime());
            timeout = timeout < 0 ? 0 : timeout;
            timer = setTimeout(function () {
                if (!$dialog.hasClass('open')) {
                    $dialog.addClass('open');
                    navigator.splashscreen.hide();
                }
                $inner.css({width: '0%'});
                $number.text('0%');
                $tip.text('下载中');
            }, timeout);
            window.resolveLocalFileSystemURL(updateConfig.basePath, function (dirEntry) {
                dirEntry.getDirectory('updates/project', {
                    create: true,
                    exclusive: false
                }, function (childEntry) {
                    downloadFile(new FileTransfer(), childEntry);
                }, function (e) {
                    goHome();
                });
            });
        };

        const downloadFile = (fileTransfer, childEntry) => {
            if (addFiles.length) {
                let file = addFiles.splice(0, 1)[0];
                fileTransfer.download(encodeURI(updateConfig.serverPath + 'apps/' + updateConfig.appName + file.filePath), childEntry.nativeURL + file.filePath, function (fileEntry) {
                    console.log('Download Finish');
                    getPercent();
                    downloadFile(fileTransfer, childEntry);
                }, function (error) {
                    console.log('Download Error: ' + JSON.stringify(error));
                    getPercent();
                    downloadFile(fileTransfer, childEntry);
                });
            } else
                deleteFile(childEntry);
        };

        const deleteFile = (childEntry) => {
            if (delFiles.length) {
                let file = delFiles.splice(0, 1)[0];
                window.resolveLocalFileSystemURL(childEntry.nativeURL + file.filePath, function (fileEntry) {
                    fileEntry.remove(function () {
                        console.log('Delete Success');
                        getPercent();
                        deleteFile(childEntry);
                    }, function (error) {
                        console.log('Delete Error: ' + JSON.stringify(error));
                        getPercent();
                        deleteFile(childEntry);
                    }, function () {
                        console.log('Delete Not Exist');
                        getPercent();
                        deleteFile(childEntry);
                    });
                }, function (error) {
                    console.log(JSON.stringify(error));
                    getPercent();
                    deleteFile(childEntry);
                });
            } else {
                navigator.appmanager.md5Project();
                goHome();
            }
        };

        const goHome = () => {
            if (timer)
                clearTimeout(timer);
            $dialog.removeClass('open');
            navigator.splashscreen.show();
            let now = new Date(), timeout = 0;
            if (now.getTime() - date.getTime() < 3000) {
                timeout = 3000 - (now.getTime() - date.getTime());
                setTimeout(function () {
                    window.location.href = updateConfig.basePath + 'updates/project/index.html';
                }, timeout)
            } else
                window.location.href = updateConfig.basePath + 'updates/project/index.html';
        };

        const getPercent = () => {
            let percent = parseInt((1 - ((addFiles.length + delFiles.length) / count)) * 100);
            $inner.css({width: percent + '%'});
            $number.text(percent + '%');
        };

    }
}