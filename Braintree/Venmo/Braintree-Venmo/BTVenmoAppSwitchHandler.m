#import "BTVenmoAppSwitchHandler.h"
#import "BTVenmoAppSwitchRequestURL.h"
#import "BTVenmoAppSwitchReturnURL.h"
#import "BTClient+BTVenmo.h"
#import "BTClient_Metadata.h"

@interface BTVenmoAppSwitchHandler ()
@property (nonatomic, strong) BTClient *client;
@end

@implementation BTVenmoAppSwitchHandler

@synthesize returnURLScheme;
@synthesize delegate;

- (BOOL)initiateAppSwitchWithClient:(BTClient *)client delegate:(__unused id<BTAppSwitchingDelegate>)theDelegate {

    client = [client copyWithMetadata:^(BTClientMutableMetadata *metadata) {
        metadata.source = BTClientMetadataSourceVenmoApp;
    }];

    self.client = client;

    if ([client btVenmo_status] == BTVenmoStatusOff) {
        [client postAnalyticsEvent:@"ios.venmo.appswitch.initiate.venmo-status-off"];
        return NO;
    }

    if (!self.returnURLScheme) {
        [client postAnalyticsEvent:@"ios.venmo.appswitch.initiate.nil-return-url-scheme"];
        return NO;
    }

    if (!client.merchantId) {
        [client postAnalyticsEvent:@"ios.venmo.appswitch.initiate.nil-merchant-id"];
        return NO;
    }

    if (![BTVenmoAppSwitchRequestURL isAppSwitchAvailable]) {
        [client postAnalyticsEvent:@"ios.venmo.appswitch.initiate.app-switch-unavailable"];
        return NO;
    }

    BOOL offline = client.btVenmo_status == BTVenmoStatusOffline;

    NSURL *venmoAppSwitchURL = [BTVenmoAppSwitchRequestURL appSwitchURLForMerchantID:client.merchantId returnURLScheme:self.returnURLScheme offline:offline];
    self.delegate = theDelegate;

    if ([self.delegate respondsToSelector:@selector(appSwitcherWillSwitch:)]) {
        [self.delegate appSwitcherWillSwitch:self];
    }
    BOOL success = [[UIApplication sharedApplication] openURL:venmoAppSwitchURL];
    if (success) {
        [client postAnalyticsEvent:@"ios.venmo.appswitch.initiate.success"];
    } else {
        [client postAnalyticsEvent:@"ios.venmo.appswitch.initiate.failure"];
    }
    return success;
}

+ (BOOL)isAvailableForClient:(BTClient *)client {
    return [BTVenmoAppSwitchRequestURL isAppSwitchAvailable] && client.btVenmo_status != BTVenmoStatusOff;
}

- (BOOL)canHandleReturnURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
    return [BTVenmoAppSwitchReturnURL isValidURL:url sourceApplication:sourceApplication];
}

- (void)handleReturnURL:(NSURL *)url {
    if ([self.delegate respondsToSelector:@selector(appSwitcherWillCreatePaymentMethod:)]) {
        [self.delegate appSwitcherWillCreatePaymentMethod:self];
    }
    BTVenmoAppSwitchReturnURL *returnURL = [[BTVenmoAppSwitchReturnURL alloc] initWithURL:url];
    switch (returnURL.state) {
        case BTVenmoAppSwitchReturnURLStateSucceeded: {
            [self.client postAnalyticsEvent:@"ios.venmo.appswitch.handle.authorized"];
            [self.client fetchPaymentMethodWithNonce:returnURL.paymentMethod.nonce
                                             success:^(BTPaymentMethod *paymentMethod){
                                                 [self.client postAnalyticsEvent:@"ios.venmo.appswitch.handle.success"];
                                                 [self.delegate appSwitcher:self didCreatePaymentMethod:paymentMethod];
                                             }
                                             failure:^(NSError *error){
                                                 [self.client postAnalyticsEvent:@"ios.venmo.appswitch.handle.client-failure"];
                                                 [self.delegate appSwitcher:self didFailWithError:error];
                                             }];
            break;
        }
        case BTVenmoAppSwitchReturnURLStateFailed:
            [self.client postAnalyticsEvent:@"ios.venmo.appswitch.handle.error"];
            [self.delegate appSwitcher:self didFailWithError:returnURL.error];
            break;
        case BTVenmoAppSwitchReturnURLStateCanceled:
            [self.client postAnalyticsEvent:@"ios.venmo.appswitch.handle.cancel"];
            [self.delegate appSwitcherDidCancel:self];
            break;
        default:
            // should not happen
            break;
    }
}

+ (instancetype)sharedHandler {
    static BTVenmoAppSwitchHandler *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[BTVenmoAppSwitchHandler alloc] init];
    });
    return instance;
}

@end