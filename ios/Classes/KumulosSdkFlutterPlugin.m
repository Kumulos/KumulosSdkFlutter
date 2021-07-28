#import "KumulosSdkFlutterPlugin.h"
#import <KumulosSDK/KumulosSDK.h>
@import CoreLocation;

static const NSString* KSFlutterSdkVersion = @"1.1.0";

#pragma mark - Event bridge helper

@interface KumulosEventStreamHandler : NSObject<FlutterStreamHandler>

@property FlutterEventSink eventSink;
@property NSMutableArray<id>* eventQueue;

@end

@implementation KumulosEventStreamHandler

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.eventQueue = [[NSMutableArray alloc] initWithCapacity:1];
    }
    return self;
}

- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    @synchronized (self.class) {
        self.eventSink = events;

        for (id event in self.eventQueue) {
            self.eventSink(event);
        }

        [self.eventQueue removeAllObjects];
    }

    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
    @synchronized (self.class) {
        self.eventSink = nil;
        [self.eventQueue removeAllObjects];
    }

    return nil;
}

- (void) send:(_Nonnull id)event {
    @synchronized (self.class) {
        if (!self.eventSink) {
            [self.eventQueue addObject:event];
            return;
        }

        self.eventSink(event);
    }
}

@end

#pragma mark - Plugin implementation

@implementation KumulosSdkFlutterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    NSString* key = [registrar lookupKeyForAsset:@"kumulos.json"];
    NSString* configPath = [NSBundle.mainBundle pathForResource:key ofType:nil];

    if (!configPath) {
        NSLog(@"kumulos.json config asset not found, aborting");
        return;
    }

    NSError* err = nil;
    NSInputStream* configReader = [NSInputStream inputStreamWithFileAtPath:configPath];
    [configReader open];

    NSDictionary* configValues = [NSJSONSerialization JSONObjectWithStream:configReader options:0 error:&err];

    [configReader close];

    if (err != nil) {
        NSLog(@"Failed to read config: %@", err);
        return;
    }

    NSString* apiKey = configValues[@"apiKey"];
    NSString* secretKey = configValues[@"secretKey"];

    if (!apiKey || !secretKey || [apiKey isEqualToString:@""] || [secretKey isEqualToString:@""]) {
        NSLog(@"Kumulos API  key and secret key are required, aborting");
        return;
    }

    FlutterMethodChannel* channel = [FlutterMethodChannel
      methodChannelWithName:@"kumulos_sdk_flutter"
            binaryMessenger:registrar.messenger];
    KumulosSdkFlutterPlugin* instance = [KumulosSdkFlutterPlugin new];
    [registrar addMethodCallDelegate:instance channel:channel];
    // We have to register for applicaiton lifecycle delegate methods to make
    // background push / fetch handling work properly.
    [registrar addApplicationDelegate:instance];

    // Method/event channels
    FlutterEventChannel* eventChannel = [FlutterEventChannel eventChannelWithName:@"kumulos_sdk_flutter_events" binaryMessenger:registrar.messenger];

    KumulosEventStreamHandler* streamHandler = [KumulosEventStreamHandler new];
    [eventChannel setStreamHandler:streamHandler];

    KSConfig* config = [KSConfig configWithAPIKey:apiKey andSecretKey:secretKey];

    // Crash reporting
    if (configValues[@"enableCrashReporting"]) {
        [config enableCrashReporting];
    }

    // Push handlers
    [config setPushOpenedHandler:^(KSPushNotification * _Nonnull notification) {
        [streamHandler send:@{@"type": @"push.opened",
                              @"data": [KumulosSdkFlutterPlugin pushToDict:notification]
        }];
    }];

    if (@available(iOS 10.0, *)) {
        [config setPushReceivedInForegroundHandler:^(KSPushNotification * _Nonnull notification) {
            [streamHandler send:@{@"type": @"push.received",
                                  @"data": [KumulosSdkFlutterPlugin pushToDict:notification]
            }];
        }];
    }

    // In-app
    if ([configValues[@"inAppConsentStrategy"] isEqualToString:@"auto-enroll"]) {
        [config enableInAppMessaging:KSInAppConsentStrategyAutoEnroll];
    } else if ([configValues[@"inAppConsentStrategy"] isEqualToString:@"explicit-by-user"]) {
        [config enableInAppMessaging:KSInAppConsentStrategyExplicitByUser];
    }

    if ([configValues[@"inAppConsentStrategy"] isEqualToString:@"auto-enroll"] || [configValues[@"inAppConsentStrategy"] isEqualToString:@"explicit-by-user"]) {
        [config setInAppDeepLinkHandler:^(NSDictionary * _Nonnull data) {
            [streamHandler send:@{@"type": @"in-app.deepLinkPressed",
                                  @"data": data
            }];
        }];
    }

    // Deep linking
    id ddlOption = configValues[@"enableDeferredDeepLinking"];
    if (ddlOption != nil) {
        KSDeepLinkHandlerBlock ddlHandler = ^(KSDeepLinkResolution resolution, NSURL * _Nonnull url, KSDeepLink * _Nullable link) {
            [streamHandler send:@{@"type": @"deep-linking.linkResolved",
                                  @"data": @{
                                          @"url": url.absoluteString,
                                          @"resolution": @(resolution),
                                          @"link": link ? [KumulosSdkFlutterPlugin linkToDict:link] : NSNull.null
                                  }
            }];
        };
        if ([ddlOption isKindOfClass:NSString.class]) {
            [config enableDeepLinking:ddlOption deepLinkHandler:ddlHandler];
        } else if (ddlOption) {
            [config enableDeepLinking:ddlHandler];
        }
    }

#if DEBUG
    [config setTargetType:TargetTypeDebug];
#else
    [config setTargetType:TargetTypeRelease];
#endif

    // There's currently no API/const to retrieve the version of Flutter used
    [config setRuntimeInfo:@{@"id": @(9), @"version": @"unknown"}];
    [config setSdkInfo:@{@"id": @(11), @"version": KSFlutterSdkVersion}];

    [Kumulos initializeWithConfig:config];

    FlutterEventChannel* inAppEventChannel = [FlutterEventChannel eventChannelWithName:@"kumulos_sdk_flutter_events_in_app" binaryMessenger:registrar.messenger];
    KumulosEventStreamHandler* inAppStreamHandler  = [KumulosEventStreamHandler new];
    [inAppEventChannel setStreamHandler:inAppStreamHandler];

    [KumulosInApp setOnInboxUpdated:^{
        [inAppStreamHandler send:@{@"type": @"inbox.updated"}];
    }];
}

#pragma mark Method bridge

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getKeys" isEqualToString:call.method]) {
        result(@[Kumulos.shared.config.apiKey, Kumulos.shared.config.secretKey]);
        return;
    } else if([@"getInstallId" isEqualToString:call.method]) {
        result(Kumulos.installId);
        return;
    } else if ([@"getCurrentUserIdentifier" isEqualToString:call.method]) {
        result(Kumulos.currentUserIdentifier);
        return;
    } else if ([@"associateUserWithInstall" isEqualToString:call.method]) {
        NSString* identifier = call.arguments[@"id"];
        NSDictionary* attributes = call.arguments[@"attrs"];

        if (attributes) {
          [Kumulos.shared associateUserWithInstall:identifier attributes:attributes];
        } else {
          [Kumulos.shared associateUserWithInstall:identifier];
        }

        result(nil);
        return;
    } else if ([@"clearUserAssociation" isEqualToString:call.method]) {
        [Kumulos.shared clearUserAssociation];

        result(nil);
        return;
    } else if ([@"trackEvent" isEqualToString:call.method]) {
        NSString* type = call.arguments[@"type"];
        NSDictionary* props = call.arguments[@"props"];
        NSNumber* immediateFlush = call.arguments[@"flush"];

        if (immediateFlush.boolValue) {
          [Kumulos.shared trackEventImmediately:type withProperties:props];
        } else {
          [Kumulos.shared trackEvent:type withProperties:props];
        }

        result(nil);
        return;
    } else if ([@"sendLocationUpdate" isEqualToString:call.method]) {
        NSNumber* lat = call.arguments[@"lat"];
        NSNumber* lng = call.arguments[@"lng"];
        CLLocation* point = [[CLLocation alloc] initWithLatitude:lat.doubleValue longitude:lng.doubleValue];
        [Kumulos.shared sendLocationUpdate:point];

        result(nil);
        return;
    } else if ([@"pushRequestDeviceToken" isEqualToString:call.method]) {
        [Kumulos.shared pushRequestDeviceToken];

        result(nil);
        return;
    } else if ([@"pushUnregister" isEqualToString:call.method]) {
        [Kumulos.shared pushUnregister];

        result(nil);
        return;
    } else if ([@"inAppUpdateConsent" isEqualToString:call.method]) {
        NSNumber* consented = call.arguments;
        [KumulosInApp updateConsentForUser:consented.boolValue];

        result(nil);
        return;
    } else if ([@"inAppGetInboxItems" isEqualToString:call.method]) {
        NSArray<KSInAppInboxItem*>* inboxItems = [KumulosInApp getInboxItems];
        NSMutableArray<NSDictionary*>* items = [[NSMutableArray alloc] initWithCapacity:inboxItems.count];

        NSDateFormatter* formatter = [NSDateFormatter new];
        [formatter setTimeStyle:NSDateFormatterFullStyle];
        [formatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
        [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

        for (KSInAppInboxItem* item in inboxItems) {
            [items addObject:@{@"id": item.id,
                               @"title": item.title,
                               @"subtitle": item.subtitle,
                               @"sentAt": [formatter stringFromDate:item.sentAt],
                               @"availableFrom": item.availableFrom ? [formatter stringFromDate:item.availableFrom] : NSNull.null,
                               @"availableTo": item.availableTo ? [formatter stringFromDate:item.availableTo] : NSNull.null,
                               @"dismissedAt": item.dismissedAt ? [formatter stringFromDate:item.dismissedAt] : NSNull.null,
                               @"data": item.data ?: NSNull.null,
                               @"isRead": @(item.isRead),
                               @"imageUrl": [item getImageUrl] ? [item getImageUrl].absoluteString : NSNull.null
            }];
        }

        result(items);
        return;
    } else if ([@"inAppPresentInboxMessage" isEqualToString:call.method]) {
        NSNumber* ident = call.arguments;
        KSInAppMessagePresentationResult presentationResult = KSInAppMessagePresentationFailed;

        NSArray<KSInAppInboxItem*>* inboxItems = [KumulosInApp getInboxItems];
        for (KSInAppInboxItem* msg in inboxItems) {
            if ([msg.id isEqualToNumber:ident]) {
                presentationResult = [KumulosInApp presentInboxMessage:msg];
                break;
            }
        }

        result(@(presentationResult));
        return;
    } else if ([@"inAppDeleteMessageFromInbox" isEqualToString:call.method]) {
        NSNumber* ident = call.arguments;
        BOOL opResult = NO;

        NSArray<KSInAppInboxItem*>* inboxItems = [KumulosInApp getInboxItems];
        for (KSInAppInboxItem* msg in inboxItems) {
            if ([msg.id isEqualToNumber:ident]) {
                opResult = [KumulosInApp deleteMessageFromInbox:msg];
                break;
            }
        }

        result(@(opResult));
        return;
    } else if ([@"inAppMarkAsRead" isEqualToString:call.method]) {
        NSNumber* ident = call.arguments;
        BOOL opResult = NO;

        NSArray<KSInAppInboxItem*>* inboxItems = [KumulosInApp getInboxItems];
        for (KSInAppInboxItem* msg in inboxItems) {
            if ([msg.id isEqualToNumber:ident]) {
                opResult = [KumulosInApp markAsRead:msg];
                break;
            }
        }

        result(@(opResult));
        return;
    } else if ([@"inAppMarkAllInboxItemsAsRead" isEqualToString:call.method]) {
        BOOL opResult = [KumulosInApp markAllInboxItemsAsRead];

        result(@(opResult));
        return;
    } else if ([@"inAppGetInboxSummary" isEqualToString:call.method]) {
        [KumulosInApp getInboxSummaryAsync:^(InAppInboxSummary * _Nullable inboxSummary) {
            result(@{@"totalCount": @(inboxSummary.totalCount),
                     @"unreadCount": @(inboxSummary.unreadCount)
                   });
        }];

        return;
    } else if ([@"reportCrash" isEqualToString:call.method]) {
        NSString* error = call.arguments[@"error"];
        NSString* stackTrace = call.arguments[@"stackTrace"];
        NSNumber* uncaught = call.arguments[@"uncaught"];

        NSDictionary* properties = @{
            @"format": @"flutter",
            @"uncaught": @(uncaught.boolValue),
            @"report": @{
                    @"message": error,
                    @"stackTrace": stackTrace
            }
        };

        [Kumulos.shared trackEventImmediately:@"k.crash.loggedException" withProperties:properties];

        result(nil);
        return;
    }

    result(FlutterMethodNotImplemented);
}

#pragma mark Push

- (BOOL)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    // This handler has to be implemented for Flutter to correctly forward in-app tickles
    // to the SDK. If no plugins want the delegate methods, Flutter eats them.
    return NO;
}

+ (NSDictionary*) pushToDict:(KSPushNotification*)notification {
    NSDictionary* alert = notification.aps[@"alert"];

    return @{@"id": notification.id,
             @"title": alert ? alert[@"title"] : NSNull.null,
             @"message": alert ? alert[@"body"] : NSNull.null,
             @"data": notification.data ?: NSNull.null,
             @"url": notification.url ? [notification.url absoluteString] : NSNull.null,
             @"actionId": notification.actionIdentifier ? notification.actionIdentifier : NSNull.null
    };
}

#pragma mark DDL

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void (^)(NSArray * _Nonnull))restorationHandler {
    return [Kumulos application:application continueUserActivity:userActivity restorationHandler:restorationHandler];
}

+ (NSDictionary*) linkToDict:(KSDeepLink*)link {
    return @{@"content": @{
                     @"title": link.content.title ?: NSNull.null,
                     @"description": link.content.description ?: NSNull.null
             },
             @"data": link.data ?: NSNull.null
    };
}

@end
