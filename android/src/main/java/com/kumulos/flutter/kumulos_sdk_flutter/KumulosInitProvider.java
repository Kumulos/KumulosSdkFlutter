package com.kumulos.flutter.kumulos_sdk_flutter;

import android.app.Application;
import android.content.ContentProvider;
import android.content.ContentValues;
import android.content.res.AssetManager;
import android.database.Cursor;
import android.net.Uri;
import android.text.TextUtils;
import android.util.JsonReader;
import android.util.JsonToken;
import android.util.Log;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import com.kumulos.android.DeferredDeepLinkHandlerInterface;
import com.kumulos.android.Kumulos;
import com.kumulos.android.KumulosConfig;
import com.kumulos.android.KumulosInApp;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.UnsupportedEncodingException;
import java.util.HashMap;
import java.util.Map;

import io.flutter.plugin.common.EventChannel;

public class KumulosInitProvider extends ContentProvider {
    private static final String TAG = KumulosInitProvider.class.getName();

    private static final String SDK_VERSION = "1.1.0";
    private static final int RUNTIME_TYPE = 9;
    private static final int SDK_TYPE = 11;

    private static final String KEY_API_KEY = "apiKey";
    private static final String KEY_SECRET_KEY = "secretKey";
    private static final String KEY_ENABLE_CRASH_REPORTING = "enableCrashReporting";
    private static final String KEY_IN_APP_CONSENT_STRATEGY = "inAppConsentStrategy";
    private static final String IN_APP_AUTO_ENROLL = "auto-enroll";
    private static final String IN_APP_EXPLICIT_BY_USER = "explicit-by-user";
    private static final String KEY_ENABLE_DDL = "enableDeferredDeepLinking";

    @Override
    public boolean onCreate() {
        KumulosConfig.Builder config = null;
        try {
            config = tryReadConfig();
        } catch (IOException e) {
            e.printStackTrace();
            return true;
        }
        if (null == config) {
            Log.i(TAG, "Skipping init, no config file found...");
            return true;
        }

        Application application = (Application) getContext().getApplicationContext();

        JSONObject runtimeInfo = new JSONObject();
        JSONObject sdkInfo = new JSONObject();

        try {
            runtimeInfo.put("id", RUNTIME_TYPE);

            // There's currently no API/const to retrieve the version of Flutter used
            runtimeInfo.put("version", "unknown");
            sdkInfo.put("id", SDK_TYPE);
            sdkInfo.put("version", SDK_VERSION);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        config.setRuntimeInfo(runtimeInfo);
        config.setSdkInfo(sdkInfo);

        Kumulos.initialize(application, config.build());

        return true;
    }

    @Nullable
    @Override
    public Cursor query(@NonNull Uri uri, @Nullable String[] projection, @Nullable String selection, @Nullable String[] selectionArgs, @Nullable String sortOrder) {
        return null;
    }

    @Nullable
    @Override
    public String getType(@NonNull Uri uri) {
        return null;
    }

    @Nullable
    @Override
    public Uri insert(@NonNull Uri uri, @Nullable ContentValues values) {
        return null;
    }

    @Override
    public int delete(@NonNull Uri uri, @Nullable String selection, @Nullable String[] selectionArgs) {
        return 0;
    }

    @Override
    public int update(@NonNull Uri uri, @Nullable ContentValues values, @Nullable String selection, @Nullable String[] selectionArgs) {
        return 0;
    }

    @Nullable
    private KumulosConfig.Builder tryReadConfig() throws IOException {
        JsonReader reader = getConfigReader();
        if (null == reader) {
            return null;
        }

        String apiKey = null;
        String secretKey = null;
        boolean enableCrashReporting = false;
        String inAppConsentStrategy = null;
        boolean enableDeepLinking = false;
        String deepLinkingCname = null;

        try {
            reader.beginObject();

            while (reader.hasNext()) {
                String name = reader.nextName();
                if (name.equals(KEY_API_KEY)) {
                    apiKey = reader.nextString();
                } else if (name.equals(KEY_SECRET_KEY)) {
                    secretKey = reader.nextString();
                } else if (name.equals(KEY_ENABLE_CRASH_REPORTING)) {
                    enableCrashReporting = reader.nextBoolean();
                } else if (name.equals(KEY_IN_APP_CONSENT_STRATEGY)) {
                    inAppConsentStrategy = reader.nextString();
                } else if (name.equals(KEY_ENABLE_DDL)) {
                    JsonToken tok = reader.peek();
                    if (JsonToken.BOOLEAN == tok) {
                        enableDeepLinking = reader.nextBoolean();
                    } else if (JsonToken.STRING == tok) {
                        enableDeepLinking = true;
                        deepLinkingCname = reader.nextString();
                    } else {
                        reader.skipValue();
                    }
                } else {
                    reader.skipValue();
                }
            }
            reader.endObject();
        } catch (IOException e) {
            e.printStackTrace();
            return null;
        } finally {
            reader.close();
        }

        if (TextUtils.isEmpty(apiKey) || TextUtils.isEmpty(secretKey)) {
            return null;
        }

        assert apiKey != null;
        assert secretKey != null;
        KumulosConfig.Builder config = new KumulosConfig.Builder(apiKey, secretKey);

        Kumulos.setPushActionHandler(new PushReceiver.PushActionHandler());

        if (enableCrashReporting) {
            config.enableCrashReporting();
        }

        if (null != inAppConsentStrategy) {
            configureInAppMessaging(config, inAppConsentStrategy);
        }

        if (enableDeepLinking) {
            configureDeepLinking(config, deepLinkingCname);
        }

        return config;
    }

    private void configureInAppMessaging(@NonNull KumulosConfig.Builder config, @NonNull String inAppConsentStrategy) {
        if (IN_APP_AUTO_ENROLL.equals(inAppConsentStrategy)) {
            config.enableInAppMessaging(KumulosConfig.InAppConsentStrategy.AUTO_ENROLL);
        } else if (IN_APP_EXPLICIT_BY_USER.equals(inAppConsentStrategy)) {
            config.enableInAppMessaging(KumulosConfig.InAppConsentStrategy.EXPLICIT_BY_USER);
        }

        if (IN_APP_AUTO_ENROLL.equals(inAppConsentStrategy) || IN_APP_EXPLICIT_BY_USER.equals(inAppConsentStrategy)) {
            KumulosInApp.setDeepLinkHandler((context, data) -> {
                Map<String, Object> event = new HashMap<>(2);
                event.put("type", "in-app.deepLinkPressed");
                try {
                    event.put("data", JsonUtils.toMap(data));
                } catch (JSONException e) {
                    e.printStackTrace();
                    return;
                }
                KumulosSdkFlutterPlugin.eventSink.send(event);
            });
            KumulosInApp.setOnInboxUpdated(() -> {
                EventChannel.EventSink sink = KumulosSdkFlutterPlugin.inAppEventSink;

                if (sink == null) {
                    return;
                }

                Map<String, String> event = new HashMap<>(1);
                event.put("type", "inbox.updated");
                sink.success(event);
            });
        }
    }

    private void configureDeepLinking(@NonNull KumulosConfig.Builder config, @Nullable String deepLinkingCname) {
        DeferredDeepLinkHandlerInterface handler = (context, resolution, link, data) -> {
            Map<String, Object> linkMap = null;
            if (null != data) {
                linkMap = new HashMap<>(2);

                Map<String, Object> contentMap = new HashMap<>(2);
                contentMap.put("title", data.content.title);
                contentMap.put("description", data.content.description);

                linkMap.put("content", contentMap);

                try {
                    linkMap.put("data", data.data != null ? JsonUtils.toMap(data.data) : null);
                } catch (JSONException e) {
                    e.printStackTrace();
                }
            }

            Map<String, Object> eventData = new HashMap<>(3);
            eventData.put("url", link);
            eventData.put("resolution", resolution.ordinal());
            eventData.put("link", linkMap);

            Map<String, Object> event = new HashMap<>(2);
            event.put("type", "deep-linking.linkResolved");
            event.put("data", eventData);

            KumulosSdkFlutterPlugin.eventSink.send(event);
        };

        if (deepLinkingCname != null) {
            config.enableDeepLinking(deepLinkingCname, handler);
        } else {
            config.enableDeepLinking(handler);
        }
    }

    @Nullable
    private JsonReader getConfigReader() {
        String key = "flutter_assets" + File.separator + "kumulos.json";
        AssetManager assetManager = getContext().getAssets();
        InputStream is = null;
        try {
            is = assetManager.open(key);
        } catch (IOException e) {
            e.printStackTrace();
            return null;
        }
        JsonReader reader = null;
        try {
            reader = new JsonReader(new InputStreamReader(is, "UTF-8"));
        } catch (UnsupportedEncodingException e) {
            e.printStackTrace();
            return null;
        }
        return reader;
    }
}
