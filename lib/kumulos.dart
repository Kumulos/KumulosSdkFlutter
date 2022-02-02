import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumulos_sdk_flutter/backend.dart';
import './push.dart';

class KumulosPushNotification {
  final String? title;
  final String? message;
  final Map<String, dynamic>? data;
  final String? url;
  final String? actionId;

  KumulosPushNotification(
      this.title, this.message, this.data, this.url, this.actionId);

  KumulosPushNotification.fromMap(Map<String, dynamic> map)
      : title = map['title'],
        message = map['message'],
        data =
            map['data'] != null ? Map<String, dynamic>.from(map['data']) : null,
        url = map['url'],
        actionId = map['actionId'];
}

enum KumulosDeepLinkResolution {
  LookupFailed,
  LinkNotFound,
  LinkExpired,
  LimitExceeded,
  LinkMatched
}

class KumulosDeepLinkContent {
  final String? title;
  final String? description;

  KumulosDeepLinkContent(this.title, this.description);
}

class KumulosDeepLinkOutcome {
  final KumulosDeepLinkResolution resolution;
  final String url;
  final KumulosDeepLinkContent? content;
  final Map<String, dynamic>? linkData;

  KumulosDeepLinkOutcome(
      this.resolution, this.url, this.content, this.linkData);

  KumulosDeepLinkOutcome.fromMap(Map<String, dynamic> map)
      : resolution = KumulosDeepLinkResolution.values[map['resolution']],
        url = map['url'],
        content = map['link']['content'] != null
            ? KumulosDeepLinkContent(map['link']['content']['title'],
                map['link']['content']['description'])
            : null,
        linkData = map['link']['data'] != null
            ? Map<String, dynamic>.from(map['link']['data'])
            : null;
}

class Kumulos {
  static const _EVENT_TYPE_BEACON = 'k.engage.beaconEnteredProximity';
  static const _BEACON_TYPE_IBEACON = 1;
  static const _BEACON_TYPE_EDDYSTONE = 2;

  static const MethodChannel _channel =
      const MethodChannel('kumulos_sdk_flutter');

  // Event listeners

  static const EventChannel _eventChannel =
      const EventChannel('kumulos_sdk_flutter_events');
  static StreamSubscription? _eventStream;

  static void Function(KumulosPushNotification)? _pushOpenedHandler;
  static void Function(KumulosPushNotification)? _pushReceivedHandler;
  static void Function(Map<String, dynamic>)? _inAppDeepLinkHandler;
  static void Function(KumulosDeepLinkOutcome)? _deepLinkHandler;

  static void setEventHandlers(
      {void Function(KumulosPushNotification)? pushOpenedHandler,
      void Function(KumulosPushNotification)? pushReceivedHandler,
      void Function(Map<String, dynamic>)? inAppDeepLinkHandler,
      void Function(KumulosDeepLinkOutcome)? deepLinkHandler}) {
    _pushOpenedHandler = pushOpenedHandler;
    _pushReceivedHandler = pushReceivedHandler;
    _inAppDeepLinkHandler = inAppDeepLinkHandler;
    _deepLinkHandler = deepLinkHandler;

    if (pushOpenedHandler == null &&
        pushReceivedHandler == null &&
        inAppDeepLinkHandler == null &&
        deepLinkHandler == null) {
      _eventStream?.cancel();
      _eventStream = null;
      return;
    }

    if (_eventStream != null) {
      return;
    }

    _eventStream = _eventChannel.receiveBroadcastStream().listen((event) {
      String type = event['type'];
      Map<String, dynamic> data = Map<String, dynamic>.from(event['data']);

      switch (type) {
        case 'push.opened':
          _pushOpenedHandler?.call(KumulosPushNotification.fromMap(data));
          return;
        case 'push.received':
          _pushReceivedHandler?.call(KumulosPushNotification.fromMap(data));
          return;
        case 'in-app.deepLinkPressed':
          _inAppDeepLinkHandler?.call(data);
          return;
        case 'deep-linking.linkResolved':
          _deepLinkHandler?.call(KumulosDeepLinkOutcome.fromMap(data));
          return;
      }
    });
  }

  // Core analytics features

  static Future<String> get installId async {
    final String id = await _channel.invokeMethod('getInstallId');
    return id;
  }

  static Future<String> get currentUserIdentifier async {
    final String id = await _channel.invokeMethod('getCurrentUserIdentifier');
    return id;
  }

  static Future<void> associateUserWithInstall(
      {required String identifier, Map<String, dynamic>? attributes}) async {
    return _channel.invokeMethod(
        'associateUserWithInstall', {'id': identifier, 'attrs': attributes});
  }

  static Future<void> clearUserAssociation() {
    return _channel.invokeMethod('clearUserAssociation');
  }

  static void trackEvent(
      {required String eventType, Map<String, dynamic>? properties}) {
    _channel.invokeMethod(
        'trackEvent', {'type': eventType, 'props': properties, 'flush': false});
  }

  static void trackEventImmediately(
      {required String eventType, Map<String, dynamic>? properties}) {
    _channel.invokeMethod(
        'trackEvent', {'type': eventType, 'props': properties, 'flush': true});
  }

  // Location features

  static void sendLocationUpdate(
      {required double latitude, required double longitude}) {
    _channel.invokeMethod(
        'sendLocationUpdate', {'lat': latitude, 'lng': longitude});
  }

  static void sendiBeaconProximity(
      {required String proximityUuid,
      required int major,
      required int minor,
      int proximity = 0}) {
    Kumulos.trackEventImmediately(eventType: _EVENT_TYPE_BEACON, properties: {
      'type': _BEACON_TYPE_IBEACON,
      'uuid': proximityUuid,
      'major': major,
      'minor': minor,
      'proximity': proximity
    });
  }

  static void sendEddystoneBeaconProximity(
      {required String hexNamespace,
      required String hexInstance,
      double? distanceMetres}) {
    var props = {
      'type': _BEACON_TYPE_EDDYSTONE,
      'namespace': hexNamespace,
      'instance': hexInstance,
    };

    if (null != distanceMetres) {
      props['distance'] = distanceMetres;
    }

    Kumulos.trackEventImmediately(
        eventType: _EVENT_TYPE_BEACON, properties: props);
  }

  // Push features

  static void pushRequestDeviceToken() {
    _channel.invokeMethod('pushRequestDeviceToken');
  }

  static void pushUnregister() {
    _channel.invokeMethod('pushUnregister');
  }

  static Future<PushChannelManager> get pushChannelManager async {
    List<String> keys =
        List<String>.from(await _channel.invokeMethod('getKeys'));
    return PushChannelManager(keys[0], keys[1]);
  }

  // Crash features

  static void onFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);

    if (details.silent) {
      return;
    }

    Kumulos.logUncaughtError(
        details.exceptionAsString(), details.stack ?? StackTrace.empty);
  }

  static Future<void> logUncaughtError(Object error, StackTrace stackTrace) {
    return _logError(error, stackTrace, true);
  }

  static Future<void> logError(Object error, StackTrace stackTrace) async {
    return _logError(error, stackTrace, false);
  }

  static Future<void> _logError(
      Object error, StackTrace stackTrace, bool uncaught) async {
    return _channel.invokeMethod('reportCrash', {
      "error": error.toString(),
      "stackTrace": stackTrace.toString(),
      "uncaught": uncaught
    });
  }

  // BaaS features

  static Future<KumulosBackendClient> get backendRpcClient async {
    List<String> keys =
        List<String>.from(await _channel.invokeMethod('getKeys'));
    String installId = await Kumulos.installId;

    return KumulosBackendClient(keys[0], keys[1], installId);
  }
}

// In-app features

enum KumulosInAppPresentationResult { Presented, Expired, Failed }

class KumulosInAppInboxItem {
  final int id;
  final String title;
  final String subtitle;
  final DateTime? availableFrom; // Date?
  final DateTime? availableTo;
  final DateTime? dismissedAt;
  final DateTime sentAt;
  final Map<String, dynamic>? data;
  final bool isRead;
  final String? imageUrl;

  KumulosInAppInboxItem.fromMap(Map<String, dynamic> map)
      : this.id = map['id'],
        this.title = map['title'],
        this.subtitle = map['subtitle'],
        this.sentAt = DateTime.parse(map['sentAt']),
        this.availableFrom = map['availableFrom'] != null
            ? DateTime.parse(map['availableFrom'])
            : null,
        this.availableTo = map['availableTo'] != null
            ? DateTime.parse(map['availableTo'])
            : null,
        this.data = map['data'],
        this.dismissedAt = map['dismissedAt'] != null
            ? DateTime.parse(map['dismissedAt'])
            : null,
        this.isRead = map['isRead'],
        this.imageUrl = map['imageUrl'];
}

class KumulosInAppInboxSummary {
  final int totalCount;
  final int unreadCount;

  KumulosInAppInboxSummary(this.totalCount, this.unreadCount);
}

class KumulosInApp {
  static const EventChannel _eventChannel =
      const EventChannel('kumulos_sdk_flutter_events_in_app');
  static StreamSubscription? _eventStream;
  static Function? _inboxUpdatedHandler;

  static setOnInboxUpdatedHandler(Function? handler) {
    _inboxUpdatedHandler = handler;

    if (handler == null) {
      _eventStream?.cancel();
      _eventStream = null;
      return;
    }

    if (_eventStream != null) {
      return;
    }

    _eventStream = _eventChannel.receiveBroadcastStream().listen((event) {
      String type = event['type'];
      // Map<String, dynamic> data = Map<String, dynamic>.from(event['data']);

      switch (type) {
        case 'inbox.updated':
          _inboxUpdatedHandler?.call();
          break;
      }
    });
  }

  static Future<void> updateConsentForUser(bool consentGiven) async {
    return Kumulos._channel.invokeMethod('inAppUpdateConsent', consentGiven);
  }

  static Future<List<KumulosInAppInboxItem>> getInboxItems() async {
    var data = await Kumulos._channel.invokeMethod('inAppGetInboxItems');

    if (data == null) {
      return [];
    }

    var items = List.from(data)
        .map((e) => KumulosInAppInboxItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return items;
  }

  static Future<KumulosInAppPresentationResult> presentInboxMessage(
      KumulosInAppInboxItem item) async {
    var result = await Kumulos._channel
        .invokeMethod<int>('inAppPresentInboxMessage', item.id);

    return result != null
        ? KumulosInAppPresentationResult.values[result]
        : KumulosInAppPresentationResult.Failed;
  }

  static Future<bool> deleteMessageFromInbox(KumulosInAppInboxItem item) async {
    var result = await Kumulos._channel
        .invokeMethod<bool>('inAppDeleteMessageFromInbox', item.id);

    return result ?? false;
  }

  static Future<bool> markAsRead(KumulosInAppInboxItem item) async {
    var result =
        await Kumulos._channel.invokeMethod<bool>('inAppMarkAsRead', item.id);

    return result ?? false;
  }

  static Future<bool> markAllInboxItemsAsRead() async {
    var result = await Kumulos._channel
        .invokeMethod<bool>('inAppMarkAllInboxItemsAsRead');

    return result ?? false;
  }

  static Future<KumulosInAppInboxSummary?> getInboxSummary() async {
    Map<String, dynamic> result = Map<String, dynamic>.from(
        await Kumulos._channel.invokeMethod('inAppGetInboxSummary'));

    return KumulosInAppInboxSummary(
        result['totalCount'], result['unreadCount']);
  }
}
