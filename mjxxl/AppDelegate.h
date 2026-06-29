#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>
#import "LaunchView.h"

#import "WxApi.h"
@interface AppDelegate : UIResponder <UIApplicationDelegate, WXApiDelegate>
{
@public
    UIBackgroundTaskIdentifier m_kBackgroundTask;
}
@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) LaunchView *launchView;
@end
