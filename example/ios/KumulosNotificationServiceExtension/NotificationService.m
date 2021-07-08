#import "NotificationService.h"
#import <KumulosSDKExtension/KumulosNotificationService.h>

@interface NotificationService ()
@end

@implementation NotificationService
- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
   [KumulosNotificationService didReceiveNotificationRequest:request withContentHandler: contentHandler];
}
@end
