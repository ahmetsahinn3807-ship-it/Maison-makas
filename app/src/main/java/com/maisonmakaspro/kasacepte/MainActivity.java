package com.maisonmakaspro.kasacepte;

import android.Manifest;
import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.ContentResolver;
import android.content.ContentValues;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Bitmap;
import android.net.Uri;
import android.os.Build;
import android.os.Bundle;
import android.os.Environment;
import android.provider.MediaStore;
import android.util.Base64;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.CookieManager;
import android.webkit.JavascriptInterface;
import android.webkit.RenderProcessGoneDetail;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceError;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.io.OutputStream;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Kasa Cepte for Android.
 *
 * Shows the live web app (https://maisonmakaspro.github.io/KASA-CEPTE/) full screen,
 * so every update published on GitHub appears in the app automatically. Records live
 * in Firebase, so signing in shows the same data as the phone's web app.
 *
 * Extra Android support: picking a backup file ("Yedekten yukle") and saving the
 * backup the page creates ("Yedek al") into the phone's Downloads folder.
 */
public class MainActivity extends Activity {

    private static final String APP_URL = "https://maisonmakaspro.github.io/KASA-CEPTE/";
    private static final String APP_HOST = "maisonmakaspro.github.io";
    private static final String APP_PATH = "/kasa-cepte/"; // compared in lower case

    private static final int REQ_FILE = 1001;
    private static final int REQ_STORAGE = 1002;

    /** Hands files the page "downloads" (a[download] with blob:/data: links) to Android. */
    private static final String DOWNLOAD_SHIM = """
            (function () {
              if (window.__kasaAndroid) return;
              window.__kasaAndroid = true;
              var blobs = {};
              var create = URL.createObjectURL;
              URL.createObjectURL = function (obj) {
                var url = create.apply(URL, arguments);
                try { if (obj instanceof Blob) blobs[url] = obj; } catch (e) {}
                return url;
              };
              function send(blob, name) {
                var reader = new FileReader();
                reader.onload = function () {
                  var s = String(reader.result || "");
                  var i = s.indexOf(",");
                  KasaAndroid.saveFile(i >= 0 ? s.substring(i + 1) : "", name || "", blob.type || "application/octet-stream");
                };
                reader.onerror = function () { KasaAndroid.saveFailed(); };
                reader.readAsDataURL(blob);
              }
              function handle(a) {
                if (!a || !a.hasAttribute || !a.hasAttribute("download")) return false;
                var href = String(a.href || "");
                var name = a.getAttribute("download") || "";
                if (href.indexOf("blob:") === 0 && blobs[href]) { send(blobs[href], name); return true; }
                if (href.indexOf("blob:") === 0 || href.indexOf("data:") === 0) {
                  fetch(href).then(function (r) { return r.blob(); })
                    .then(function (b) { send(b, name); })
                    .catch(function () { KasaAndroid.saveFailed(); });
                  return true;
                }
                return false;
              }
              var click = HTMLAnchorElement.prototype.click;
              HTMLAnchorElement.prototype.click = function () {
                if (handle(this)) return;
                return click.apply(this, arguments);
              };
              document.addEventListener("click", function (e) {
                var t = e.target;
                var a = t && t.closest ? t.closest("a[download]") : null;
                if (a && handle(a)) { e.preventDefault(); e.stopPropagation(); }
              }, true);
            })();
            """;

    private FrameLayout root;
    private WebView web;
    private LinearLayout errorBox;
    private ValueCallback<Uri[]> fileCallback;
    private volatile String currentUrl = APP_URL;
    private boolean mainFrameFailed;

    // Waiting for the storage permission (Android 7-9 only)
    private byte[] pendingBytes;
    private String pendingName;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        root = new FrameLayout(this);
        errorBox = buildErrorBox();
        root.addView(errorBox, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));
        setContentView(root);

        createWebView();
        if (savedInstanceState == null || web.restoreState(savedInstanceState) == null) {
            web.loadUrl(APP_URL);
        }
    }

    private void createWebView() {
        web = new WebView(this);
        web.setBackgroundColor(getColor(R.color.bg));
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        root.addView(web, 0, new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(false);
        s.setSupportMultipleWindows(false);
        s.setJavaScriptCanOpenWindowsAutomatically(false);
        s.setMediaPlaybackRequiresUserGesture(true);
        s.setUserAgentString(s.getUserAgentString() + " KasaCepteAndroid/1.0");

        CookieManager cookies = CookieManager.getInstance();
        cookies.setAcceptCookie(true);
        cookies.setAcceptThirdPartyCookies(web, true);

        web.addJavascriptInterface(new Bridge(), "KasaAndroid");
        web.setWebViewClient(new AppClient());
        web.setWebChromeClient(new ChromeClient());
        web.setDownloadListener((url, userAgent, contentDisposition, mimeType, length) -> {
            if (url == null) return;
            if (url.startsWith("blob:") || url.startsWith("data:")) {
                // Fallback if a download slips past DOWNLOAD_SHIM
                web.evaluateJavascript("fetch(" + JSONObject.quote(url) + ")"
                        + ".then(function(r){return r.blob();})"
                        + ".then(function(b){var f=new FileReader();f.onload=function(){"
                        + "var s=String(f.result||'');var i=s.indexOf(',');"
                        + "KasaAndroid.saveFile(i>=0?s.substring(i+1):'','',b.type||'application/octet-stream');};"
                        + "f.readAsDataURL(b);})"
                        + ".catch(function(){KasaAndroid.saveFailed();});", null);
            } else {
                openOutside(Uri.parse(url));
            }
        });
    }

    private class AppClient extends WebViewClient {
        @Override
        public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
            // Frames inside the page (e.g. Firebase sign-in helpers) load normally.
            if (!request.isForMainFrame()) return false;
            Uri uri = request.getUrl();
            if (isAppUri(uri)) return false;
            String scheme = (uri == null || uri.getScheme() == null)
                    ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
            if (scheme.equals("blob") || scheme.equals("data")
                    || scheme.equals("about") || scheme.equals("javascript")) {
                return true;
            }
            // Any other address opens outside the app (browser, phone, WhatsApp...)
            openOutside(uri);
            return true;
        }

        @Override
        public void onPageStarted(WebView view, String url, Bitmap favicon) {
            if (url != null) currentUrl = url;
            mainFrameFailed = false;
        }

        @Override
        public void onPageFinished(WebView view, String url) {
            if (url != null) currentUrl = url;
            if (!mainFrameFailed) {
                errorBox.setVisibility(View.GONE);
                view.evaluateJavascript(DOWNLOAD_SHIM, null);
            }
        }

        @Override
        public void onReceivedError(WebView view, WebResourceRequest request, WebResourceError error) {
            if (request.isForMainFrame()) {
                mainFrameFailed = true;
                errorBox.setVisibility(View.VISIBLE);
            }
        }

        @Override
        public boolean onRenderProcessGone(WebView view, RenderProcessGoneDetail detail) {
            // The page engine stopped (e.g. low memory): build a fresh view instead of crashing.
            if (view == web) {
                root.removeView(web);
                web.destroy();
                createWebView();
                web.loadUrl(APP_URL);
            }
            return true;
        }
    }

    private class ChromeClient extends WebChromeClient {
        @Override
        public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback,
                                         FileChooserParams params) {
            if (fileCallback != null) fileCallback.onReceiveValue(null);
            fileCallback = callback;
            Intent pick = new Intent(Intent.ACTION_GET_CONTENT);
            pick.addCategory(Intent.CATEGORY_OPENABLE);
            pick.setType("*/*"); // .json backups are often not tagged as JSON on phones
            if (params != null && params.getMode() == FileChooserParams.MODE_OPEN_MULTIPLE) {
                pick.putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true);
            }
            try {
                startActivityForResult(pick, REQ_FILE);
                return true;
            } catch (ActivityNotFoundException e) {
                fileCallback = null;
                toast(getString(R.string.no_picker));
                return false;
            }
        }
    }

    private class Bridge {
        @JavascriptInterface
        public void saveFile(String base64, String name, String mime) {
            if (!isAppUri(Uri.parse(currentUrl))) return;
            final byte[] bytes;
            try {
                bytes = Base64.decode(base64 == null ? "" : base64, Base64.DEFAULT);
            } catch (IllegalArgumentException e) {
                runOnUiThread(() -> toast(getString(R.string.save_failed)));
                return;
            }
            final String type = (mime == null || mime.isEmpty()) ? "application/octet-stream" : mime;
            final String fileName = cleanName(name, type);
            runOnUiThread(() -> saveDownload(bytes, fileName, type));
        }

        @JavascriptInterface
        public void saveFailed() {
            runOnUiThread(() -> toast(getString(R.string.save_failed)));
        }
    }

    private void saveDownload(byte[] bytes, String name, String mime) {
        if (Build.VERSION.SDK_INT >= 29) {
            try {
                ContentValues values = new ContentValues();
                values.put(MediaStore.MediaColumns.DISPLAY_NAME, name);
                values.put(MediaStore.MediaColumns.MIME_TYPE, mime);
                values.put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS);
                ContentResolver resolver = getContentResolver();
                Uri item = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values);
                if (item == null) throw new IllegalStateException("insert failed");
                try (OutputStream out = resolver.openOutputStream(item)) {
                    if (out == null) throw new IllegalStateException("no stream");
                    out.write(bytes);
                }
                toast(getString(R.string.saved, name));
            } catch (Exception e) {
                toast(getString(R.string.save_failed));
            }
        } else if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE)
                != PackageManager.PERMISSION_GRANTED) {
            pendingBytes = bytes;
            pendingName = name;
            requestPermissions(new String[]{Manifest.permission.WRITE_EXTERNAL_STORAGE}, REQ_STORAGE);
        } else {
            saveLegacy(bytes, name);
        }
    }

    @SuppressWarnings("deprecation")
    private void saveLegacy(byte[] bytes, String name) {
        try {
            File dir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS);
            if (!dir.isDirectory() && !dir.mkdirs()) throw new IllegalStateException("no folder");
            String base = name;
            String ext = "";
            int dot = name.lastIndexOf('.');
            if (dot > 0) {
                base = name.substring(0, dot);
                ext = name.substring(dot);
            }
            File file = new File(dir, name);
            for (int n = 1; file.exists(); n++) file = new File(dir, base + " (" + n + ")" + ext);
            try (FileOutputStream out = new FileOutputStream(file)) {
                out.write(bytes);
            }
            toast(getString(R.string.saved, file.getName()));
        } catch (Exception e) {
            toast(getString(R.string.save_failed));
        }
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == REQ_STORAGE) {
            byte[] bytes = pendingBytes;
            String name = pendingName;
            pendingBytes = null;
            pendingName = null;
            if (bytes == null) return;
            if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                saveLegacy(bytes, name);
            } else {
                toast(getString(R.string.need_storage));
            }
            return;
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == REQ_FILE) {
            if (fileCallback != null) {
                Uri[] result = null;
                if (resultCode == RESULT_OK && data != null) {
                    ClipData clip = data.getClipData();
                    if (clip != null && clip.getItemCount() > 0) {
                        result = new Uri[clip.getItemCount()];
                        for (int k = 0; k < result.length; k++) result[k] = clip.getItemAt(k).getUri();
                    } else if (data.getData() != null) {
                        result = new Uri[]{data.getData()};
                    }
                }
                fileCallback.onReceiveValue(result);
                fileCallback = null;
            }
            return;
        }
        super.onActivityResult(requestCode, resultCode, data);
    }

    private LinearLayout buildErrorBox() {
        LinearLayout box = new LinearLayout(this);
        box.setOrientation(LinearLayout.VERTICAL);
        box.setGravity(Gravity.CENTER);
        box.setPadding(dp(32), dp(32), dp(32), dp(32));
        box.setBackgroundColor(getColor(R.color.bg));
        box.setClickable(true);
        box.setVisibility(View.GONE);

        TextView title = new TextView(this);
        title.setText(R.string.err_title);
        title.setTextSize(20);
        title.setTextColor(getColor(R.color.ink));
        title.setGravity(Gravity.CENTER);
        box.addView(title);

        TextView msg = new TextView(this);
        msg.setText(R.string.err_msg);
        msg.setTextSize(15);
        msg.setTextColor(getColor(R.color.muted));
        msg.setGravity(Gravity.CENTER);
        msg.setPadding(0, dp(8), 0, dp(24));
        box.addView(msg);

        Button retry = new Button(this);
        retry.setText(R.string.retry);
        retry.setOnClickListener(v -> {
            box.setVisibility(View.GONE);
            web.loadUrl(APP_URL);
        });
        box.addView(retry);
        return box;
    }

    private void openOutside(Uri uri) {
        if (uri == null) return;
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, uri));
        } catch (Exception e) {
            toast(getString(R.string.cant_open));
        }
    }

    private static boolean isAppUri(Uri uri) {
        if (uri == null) return false;
        String path = uri.getPath() == null ? "/" : uri.getPath();
        return "https".equalsIgnoreCase(uri.getScheme())
                && APP_HOST.equalsIgnoreCase(uri.getHost())
                && (path + "/").toLowerCase(Locale.ROOT).startsWith(APP_PATH);
    }

    private static String cleanName(String name, String mime) {
        String n = name == null ? "" : name.replaceAll("[\\\\/:*?\"<>|\\p{Cntrl}]", "_").trim();
        if (n.isEmpty() || n.startsWith(".")) {
            String stamp = new SimpleDateFormat("yyyy-MM-dd-HHmm", Locale.ROOT).format(new Date());
            n = "kasacepte-" + stamp + ("application/json".equals(mime) ? ".json" : "");
        }
        return n;
    }

    private void toast(String text) {
        Toast.makeText(this, text, Toast.LENGTH_LONG).show();
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }

    @Override
    @SuppressWarnings("deprecation")
    public void onBackPressed() {
        if (web != null && web.canGoBack()) {
            web.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (web != null) web.onPause();
        CookieManager.getInstance().flush();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (web != null) web.onResume();
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        if (web != null) web.saveState(outState);
    }

    @Override
    protected void onDestroy() {
        if (fileCallback != null) {
            fileCallback.onReceiveValue(null);
            fileCallback = null;
        }
        if (web != null) {
            root.removeView(web);
            web.destroy();
            web = null;
        }
        super.onDestroy();
    }
}
