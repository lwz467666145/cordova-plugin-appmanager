package com.chinact.mobile.plugin.appmanager;

import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.support.v4.content.FileProvider;
import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.*;
import java.security.MessageDigest;
import java.util.*;
import java.util.jar.JarEntry;
import java.util.jar.JarFile;

public class AppManager extends CordovaPlugin {

    private static Activity cordovaActivity;
    private String applicationId;
    private String dirPath;
    private String versionCode;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);
        cordovaActivity = cordova.getActivity();
    }

    @Override
    public boolean execute(final String action, final JSONArray data, final CallbackContext callbackContext) throws JSONException {
        this.applicationId = (String) BuildHelper.getBuildConfigValue(cordova.getActivity(), "APPLICATION_ID");
        this.applicationId = preferences.getString("applicationId", this.applicationId);
        this.dirPath = cordova.getActivity().getFilesDir() + "/updates/";
        try {
            String packageName = this.cordova.getActivity().getPackageName();
            PackageManager pm = this.cordova.getActivity().getPackageManager();
            PackageInfo packageInfo = pm.getPackageInfo(packageName, 0);
            versionCode = packageInfo.versionName;
        } catch (Exception e) {
            e.printStackTrace();
        }
        if ("installApp".equals(action)) {
            String name = data.getString(0);
            Intent intent = new Intent(Intent.ACTION_VIEW);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                Uri contentUri = FileProvider.getUriForFile(cordovaActivity, applicationId + ".provider", new File(cordovaActivity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), name));
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
                intent.setDataAndType(contentUri, "application/vnd.android.package-archive");
            } else
                intent.setDataAndType(Uri.fromFile(new File(cordovaActivity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), name)), "application/vnd.android.package-archive");
            cordovaActivity.startActivity(intent);
        } else if ("openApp".equals(action)) {
            String packagei = data.getString(0);
            PackageManager packageManager = cordova.getActivity().getPackageManager();
            Intent intent = packageManager.getLaunchIntentForPackage(packagei);
            if (intent != null)
                cordova.getActivity().startActivity(intent);
            else
                callbackContext.error("Not Install");
        } else if ("hasApp".equals(action)) {
            String packagei = data.getString(0);
            PackageManager packageManager = cordova.getActivity().getPackageManager();
            Intent intent = packageManager.getLaunchIntentForPackage(packagei);
            callbackContext.success(String.valueOf(intent != null));
        } else if ("exitApp".equals(action))
            this.webView.getPluginManager().postMessage("exit", null);
        else if ("getPic".equals(action)) {
            File screen = new File(dirPath + "screen.png");
            if (!screen.exists()) {
                try {
                    final int drawableId = getSplashId();
                    copyFile(cordova.getActivity().getResources().openRawResource(drawableId), dirPath + "/screen.png");
                    callbackContext.success("success");
                } catch (IOException e) {
                    e.printStackTrace();
                    callbackContext.success("error");
                }
            }
            callbackContext.success("success");
        } else if ("checkProject".equals(action)) {
            File version = new File(dirPath + "version.txt");
            if (version.exists()) {
                String currentCode = "";
                try {
                    StringBuilder sb = new StringBuilder("");
                    InputStream in = new FileInputStream(version);
                    byte[] buffer = new byte[1024];
                    int len = 0;
                    while ((len = in.read(buffer)) > 0) {
                        sb.append(new String(buffer, 0, len));
                    }
                    in.close();
                    currentCode = sb.toString();
                } catch (Exception e) {
                    e.printStackTrace();
                }
                if (versionCode.equals(currentCode) && versionCode != "")
                    callbackContext.success("nothing");
                else {
                    deleteFile(version);
                    deleteFile(new File(dirPath + "files.json"));
                    deleteFile(new File(dirPath + "project/"));
                    callbackContext.success("unzip");
                }
            } else
                callbackContext.success("unzip");
        } else if ("unzipProject".equals(action)) {
            try {
                final JarFile jarFile = new JarFile(cordova.getActivity().getApplicationInfo().sourceDir);
                final Enumeration<JarEntry> entries = jarFile.entries();
                JSONArray array = new JSONArray();
                while (entries.hasMoreElements()) {
                    final JarEntry entry = entries.nextElement();
                    final String name = entry.getName();
                    if (!entry.isDirectory() && name.startsWith("assets/www")) {
                        final String filePath = dirPath + "/project/" + name.substring(11);
                        if (!name.startsWith("assets/www/update")) {
                            if (!name.startsWith("assets/www/cordova") && !name.startsWith("assets/www/plugins")) {
                                JSONObject fileObj = new JSONObject();
                                fileObj.put("fileName", name.substring(name.lastIndexOf("/") + 1));
                                fileObj.put("filePath", "/" + name.substring(11).replaceAll("\\/", "/"));
                                fileObj.put("fileMd5", md5File(jarFile.getInputStream(entry)));
                                array.put(fileObj);
                            }
                            copyFile(jarFile.getInputStream(entry), filePath);
                        }
                    }
                }
                JSONObject root = new JSONObject();
                root.put("count", array.length());
                root.put("files", array);
                copyFile(new StringBufferInputStream(versionCode), dirPath + "/version.txt");
                copyFile(new StringBufferInputStream(root.toString()), dirPath + "/files.json");
                callbackContext.success("success");
            } catch (Exception e) {
                e.printStackTrace();
                callbackContext.success("error");
            }
        } else if ("md5Project".equals(action)) {
            File file = new File(dirPath + "/project/");
            if (file.exists()) {
                try {
                    JSONArray array = new JSONArray();
                    openDirectory(file, array, file.getPath());
                    JSONObject root = new JSONObject();
                    root.put("count", array.length());
                    root.put("files", array);
                    copyFile(new StringBufferInputStream(root.toString()), dirPath + "/files.json");
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        }
        return true;
    }

    private int getSplashId() {
        int drawableId = 0;
        String splashResource = preferences.getString("SplashScreen", "screen");
        if (splashResource != null) {
            drawableId = cordova.getActivity().getResources().getIdentifier(splashResource, "drawable", cordova.getActivity().getClass().getPackage().getName());
            if (drawableId == 0)
                drawableId = cordova.getActivity().getResources().getIdentifier(splashResource, "drawable", cordova.getActivity().getPackageName());
        }
        return drawableId;
    }

    private static void copyFile(final InputStream in, final String outPath) throws IOException {
        File dir = new File(new File(outPath).getParent());
        if (!dir.exists() || !dir.isDirectory())
            dir.mkdirs();
        OutputStream out = new FileOutputStream(outPath);
        byte[] buf = new byte[4096];
        int len;
        while ((len = in.read(buf)) > 0) {
            out.write(buf, 0, len);
        }
        in.close();
        out.close();
    }

    private static String md5File(final InputStream in) throws Exception {
        String result = "";
        byte buf[] = new byte[8192];
        int len;
        MessageDigest md5 = MessageDigest.getInstance("MD5");
        while ((len = in.read(buf)) != -1) {
            md5.update(buf, 0, len);
        }
        byte[] bytes = md5.digest();
        for (byte b : bytes) {
            String temp = Integer.toHexString(b & 0xff);
            if (temp.length() == 1)
                temp = "0" + temp;
            result += temp;
        }
        return result;
    }

    private static void deleteFile(File file) {
        if (file.exists()) {
            if (file.isDirectory()) {
                for (File child : file.listFiles())
                    deleteFile(child);
            }
            file.delete();
        }
    }

    private static void openDirectory(File file, JSONArray array, String path) throws Exception {
        if (file.exists()) {
            String filePath = file.getPath().replace(path, "");
            if (filePath.startsWith("/cordova") || filePath.startsWith("/plugins"))
                return;
            if (file.isDirectory()) {
                File[] files = file.listFiles();
                List<File> fileList = Arrays.asList(files);
                Collections.sort(fileList, new Comparator<File>() {
                    @Override
                    public int compare(File o1, File o2) {
                        if (o1.isDirectory() && o2.isFile())
                            return -1;
                        if (o1.isFile() && o2.isDirectory())
                            return 1;
                        return o1.getName().compareTo(o2.getName());
                    }
                });
                for (File child : fileList)
                    openDirectory(child, array, path);
            } else {
                JSONObject fileObj = new JSONObject();
                fileObj.put("fileName", file.getPath().substring(file.getPath().lastIndexOf("/") + 1));
                fileObj.put("filePath", file.getPath().replace(path, ""));
                fileObj.put("fileMd5", md5File(new FileInputStream(file)));
                array.put(fileObj);
            }
        }
    }

}