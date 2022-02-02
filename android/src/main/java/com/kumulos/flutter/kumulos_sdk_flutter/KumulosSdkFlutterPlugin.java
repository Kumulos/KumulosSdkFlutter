package com.kumulos.flutter.kumulos_sdk_flutter;

import android.app.Activity;
import android.content.Context;
import android.location.Location;

import androidx.annotation.NonNull;

import com.kumulos.android.InAppInboxItem;
import com.kumulos.android.Kumulos;
import com.kumulos.android.KumulosInApp;

import org.json.JSONException;
import org.json.JSONObject;

import java.lang.ref.WeakReference;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.TimeZone;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/**
 * KumulosSdkFlutterPlugin
 */
public class KumulosSdkFlutterPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private MethodChannel channel;
    private EventChannel eventChannel;
    private EventChannel inAppEventChannel;
    private Context context;
    /**
     * package
     */
    static WeakReference<Activity> currentActivityRef = new WeakReference<>(null);

    /**
     * package
     */
    static QueueingEventStreamHandler eventSink = new QueueingEventStreamHandler();
    /**
     * package
     */
    static EventChannel.EventSink inAppEventSink;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        context = flutterPluginBinding.getApplicationContext();

        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "kumulos_sdk_flutter");
        channel.setMethodCallHandler(this);

        eventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "kumulos_sdk_flutter_events");
        eventChannel.setStreamHandler(eventSink);

        inAppEventChannel = new EventChannel(flutterPluginBinding.getBinaryMessenger(), "kumulos_sdk_flutter_events_in_app");
        inAppEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink events) {
                inAppEventSink = events;
            }

            @Override
            public void onCancel(Object arguments) {
                inAppEventSink = null;
            }
        });
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        eventChannel.setStreamHandler(null);
        eventSink.onCancel(null);
        inAppEventChannel.setStreamHandler(null);
        context = null;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        currentActivityRef = new WeakReference<>(binding.getActivity());
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        currentActivityRef = new WeakReference<>(null);
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        currentActivityRef = new WeakReference<>(null);
    }

    @Override
    public void onDetachedFromActivity() {
        currentActivityRef = new WeakReference<>(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "getKeys":
                List<String> keys = new ArrayList<>(2);
                keys.add(Kumulos.getConfig().getApiKey());
                keys.add(Kumulos.getConfig().getSecretKey());

                result.success(keys);
                break;
            case "getInstallId":
                result.success(com.kumulos.android.Installation.id(context));
                break;
            case "getCurrentUserIdentifier":
                result.success(Kumulos.getCurrentUserIdentifier(context));
                break;
            case "associateUserWithInstall":
                String ident = call.argument("id");
                Map<String, Object> attrsMap = call.argument("attrs");
                JSONObject attrs = null;
                if (null != attrsMap) {
                    attrs = new JSONObject(attrsMap);
                }

                Kumulos.associateUserWithInstall(context, ident, attrs);
                result.success(null);
                break;
            case "clearUserAssociation":
                Kumulos.clearUserAssociation(context);
                result.success(null);
                break;
            case "trackEvent":
                String type = call.argument("type");
                Boolean flush = call.argument("flush");

                Map<String, Object> propsMap = call.argument("props");
                JSONObject props = null;
                if (null != propsMap) {
                    props = new JSONObject(propsMap);
                }

                if (flush) {
                    Kumulos.trackEventImmediately(context, type, props);
                } else {
                    Kumulos.trackEvent(context, type, props);
                }

                result.success(null);
                break;
            case "sendLocationUpdate":
                Double lat = call.argument("lat");
                Double lng = call.argument("lng");
                Location location = new Location("");
                location.setLatitude(lat);
                location.setLongitude(lng);
                location.setTime(System.currentTimeMillis());

                Kumulos.sendLocationUpdate(context, location);
                result.success(null);
                break;
            case "pushRequestDeviceToken":
                Kumulos.pushRegister(context);
                result.success(null);
                break;
            case "pushUnregister":
                Kumulos.pushUnregister(context);
                result.success(null);
                break;
            case "inAppUpdateConsent":
                KumulosInApp.updateConsentForUser(call.arguments());
                result.success(null);
                break;
            case "inAppGetInboxItems":
                getInboxItems(result);
                break;
            case "inAppPresentInboxMessage":
                presentInAppMessage(call, result);
                break;
            case "inAppDeleteMessageFromInbox":
                deleteInboxItem(call, result);
                boolean deleted;
                break;
            case "inAppMarkAsRead":
                markAsRead(call, result);
                break;
            case "inAppMarkAllInboxItemsAsRead":
                boolean allMarked = KumulosInApp.markAllInboxItemsAsRead(context);
                result.success(allMarked);
                break;
            case "inAppGetInboxSummary":
                KumulosInApp.getInboxSummaryAsync(context, summary -> {
                    Map<String, Object> summaryMap = new HashMap<>(2);
                    summaryMap.put("totalCount", summary.getTotalCount());
                    summaryMap.put("unreadCount", summary.getUnreadCount());
                    result.success(summaryMap);
                });
                break;
            case "reportCrash":
                String error = call.argument("error");
                String stackTrace = call.argument("stackTrace");
                Boolean uncaught = call.argument("uncaught");

                this.reportCrash(error, stackTrace, uncaught);
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void presentInAppMessage(@NonNull MethodCall call, @NonNull Result result) {
        int id = call.arguments();
        KumulosInApp.InboxMessagePresentationResult presentationResult = KumulosInApp.InboxMessagePresentationResult.FAILED;
        List<InAppInboxItem> items = KumulosInApp.getInboxItems(context);
        for (InAppInboxItem item :
                items) {
            if (item.getId() == id) {
                presentationResult = KumulosInApp.presentInboxMessage(context, item);
                break;
            }
        }
        // Map the enum ordinals into the order expected in the dart side (matches ObjC)
        switch (presentationResult) {
            case PRESENTED:
                result.success(0);
                break;
            case FAILED_EXPIRED:
                result.success(1);
                break;
            default:
                result.success(2);
                break;
        }
    }

    private void markAsRead(@NonNull MethodCall call, @NonNull Result result) {
        boolean deleted;
        int id = call.arguments();
        boolean marked = false;
        List<InAppInboxItem> items = KumulosInApp.getInboxItems(context);
        for (InAppInboxItem item : items) {
            if (id == item.getId()) {
                deleted = KumulosInApp.markAsRead(context, item);
                break;
            }
        }
        result.success(marked);
    }

    private void deleteInboxItem(@NonNull MethodCall call, @NonNull Result result) {
        int id = call.arguments();
        boolean deleted = false;
        List<InAppInboxItem> items = KumulosInApp.getInboxItems(context);
        for (InAppInboxItem item : items) {
            if (id == item.getId()) {
                deleted = KumulosInApp.deleteMessageFromInbox(context, item);
                break;
            }
        }
        result.success(deleted);
    }

    private void getInboxItems(@NonNull Result result) {
        SimpleDateFormat formatter;
        formatter = new SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'", Locale.US);
        formatter.setTimeZone(TimeZone.getTimeZone("UTC"));

        List<InAppInboxItem> inboxItems = KumulosInApp.getInboxItems(context);
        List<Map<String, Object>> results = new ArrayList<>(inboxItems.size());
        for (InAppInboxItem item : inboxItems) {
            Map<String, Object> mapped = new HashMap<>(10);
            mapped.put("id", item.getId());
            mapped.put("title", item.getTitle());
            mapped.put("subtitle", item.getSubtitle());
            mapped.put("sentAt", formatter.format(item.getSentAt()));
            mapped.put("isRead", item.isRead());
            mapped.put("data", item.getData());
            mapped.put("imageUrl", item.getImageUrl() != null ? item.getImageUrl().toString() : null);

            Date availableFrom = item.getAvailableFrom();
            Date availableTo = item.getAvailableTo();
            Date dismissedAt = item.getDismissedAt();

            if (null == availableFrom) {
                mapped.put("availableFrom", null);
            } else {
                mapped.put("availableFrom", formatter.format(availableFrom));
            }

            if (null == availableTo) {
                mapped.put("availableTo", null);
            } else {
                mapped.put("availableTo", formatter.format(availableTo));
            }

            if (null == dismissedAt) {
                mapped.put("dismissedAt", null);
            } else {
                mapped.put("dismissedAt", formatter.format(dismissedAt));
            }

            results.add(mapped);
        }
        result.success(results);
    }

    private void reportCrash(String error, String stackTrace, Boolean uncaught) {
        JSONObject properties = new JSONObject();
        try {
            JSONObject report = new JSONObject();
            report.put("message", error);
            report.put("stackTrace", stackTrace);

            properties.put("format", "flutter");
            properties.put("uncaught", uncaught);
            properties.put("report", report);
        } catch (JSONException e) {
            Kumulos.logException(e);
            return;
        }

        Kumulos.trackEventImmediately(context, "k.crash.loggedException", properties);
    }

    /**
     * package
     */
    static class QueueingEventStreamHandler implements EventChannel.StreamHandler {

        private final ArrayList<Object> eventQueue = new ArrayList<>(1);
        private EventChannel.EventSink eventSink;

        @Override
        public void onListen(Object arguments, EventChannel.EventSink events) {
            synchronized (this) {
                eventSink = events;

                for (Object event : eventQueue) {
                    eventSink.success(event);
                }

                eventQueue.clear();
            }
        }

        @Override
        public void onCancel(Object arguments) {
            synchronized (this) {
                eventSink = null;
                eventQueue.clear();
            }
        }

        public synchronized void send(Object event) {
            send(event, true);
        }

        public synchronized void send(Object event, boolean queueIfNotReady) {
            if (null == eventSink) {
                if (queueIfNotReady) {
                    eventQueue.add(event);
                }
                return;
            }

            eventSink.success(event);
        }
    }
}
