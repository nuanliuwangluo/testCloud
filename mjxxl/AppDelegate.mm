#import "AppDelegate.h"
#import "ViewController.h"
#import "WechatM.h"
#import "HttpRequest.h"
#import "UMCommon/UMCommon.h"
#import "YlhAdM.h"
#import "AppLovinSDK/AppLovinSDK.h"

@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] ;
    ViewController* pViewController  = [[ViewController alloc] init];
    _window.rootViewController = pViewController;
    [_window makeKeyAndVisible];
    
     _launchView = [[LaunchView alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [_window.rootViewController.view addSubview:_launchView.view];
    
    [WXApi registerApp:@"wx47f629be8dac75a7"
    universalLink:@"https://17hymj.snyngame.com/"];
    
    [UMConfigure initWithAppkey:@"68085792bc47b67d83463685" channel:@""];
    [UMConfigure setLogEnabled:YES];
    
    ALSdkInitializationConfiguration *initConfig = [ALSdkInitializationConfiguration configurationWithSdkKey:@"111111" builderBlock:^(ALSdkInitializationConfigurationBuilder *builder) {
        builder.mediationProvider = ALMediationProviderMAX;
    }];
    [[ALSdk shared] initializeWithConfiguration:initConfig completionHandler:^(ALSdkConfiguration *configuration) {
        
    }];
    
    if(![[UIApplication sharedApplication] backgroundRefreshStatus] == UIBackgroundRefreshStatusAvailable){
        NSLog(@"后台刷新未开启");
    }
    
    [YlhAdM initSDK];
    return YES;
    
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    m_kBackgroundTask = [application beginBackgroundTaskWithExpirationHandler:^{
        if(m_kBackgroundTask != UIBackgroundTaskInvalid )
        {
            NSLog(@">>>>>backgroundTask end");
            [application endBackgroundTask:m_kBackgroundTask];
            m_kBackgroundTask = UIBackgroundTaskInvalid;
        }
    }];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (BOOL)application:(UIApplication *)application handleOpenURL:(NSURL *)url {
    return  [WXApi handleOpenURL:url delegate:self];
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options
{
    if([MobClick handleUrl:url]){
        return YES;
    }
    if([WXApi handleOpenURL:url delegate:self]){
        return YES;
    }
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    return [WXApi handleOpenURL:url delegate:self];
}

- (BOOL)application:(UIApplication *)application continueUserActivity:(NSUserActivity *)userActivity restorationHandler:(void(^)(NSArray<id<UIUserActivityRestoring>> * __nullable restorableObjects))restorationHandler {
    return [WXApi handleOpenUniversalLink:userActivity delegate:self];
}


- (void)onReq:(BaseReq *)req {
    // 处理微信请求
    NSLog(@"收到微信请求: %@", req);
}

- (void)onResp:(BaseResp *)resp {
    NSLog(@"收到微信请求: %@", resp);
    if ([resp isKindOfClass:[SendAuthResp class]]) {
        SendAuthResp *authResp = (SendAuthResp *)resp;
        
        switch (authResp.errCode) {
            case WXSuccess: {
                // 登录成功，获取授权code
                NSString *authCode = authResp.code;
                NSLog(@"微信登录成功，授权码: %@", authCode);
                
                // 将code发送给服务器
                [self sendAuthCodeToServer:authCode];
                break;
            }
                
            case WXErrCodeUserCancel: {
                NSDictionary *dict = @{ @"code":@(WechatLoginDenied), @"msg":@"用户取消微信登录"};
                [[WechatM wechatM] backResult:dict];
                NSLog(@"用户取消微信登录");
                break;
            }
                
            case WXErrCodeAuthDeny: {
                NSDictionary *dict = @{ @"code":@(WechatAuthDenied), @"msg":@"用户拒绝微信授权"};
                [[WechatM wechatM] backResult:dict];
                NSLog(@"用户拒绝微信授权");
                break;
            }
                
            default: {
                NSString *errorMsg = [NSString stringWithFormat:@"微信登录失败，错误码: %d, 错误信息: %@", authResp.errCode, authResp.errStr ?: @"未知错误"];
                NSLog(@"%@", errorMsg);
                break;
            }
        }
    }
    
    if([resp isKindOfClass:[SendMessageToWXResp class]]){
        SendMessageToWXResp *messageResp = (SendMessageToWXResp *)resp;
        switch (messageResp.errCode) {
            case WXSuccess:{
                NSLog(@"分享成功");
                break;
            }
            case WXErrCodeUserCancel:{
                NSLog(@"用户取消");
                break;
            }
            case WXErrCodeSentFail:{
                NSLog(@"发送失败");
                break;
            }
            default:
                break;
        }
    }
}

- (void)sendAuthCodeToServer:(NSString *)authCode {
    if (!authCode || authCode.length == 0) {
        NSLog(@"授权码为空");
        return;
    }
    [self requestWechatLoginToken:authCode];
}

// 获取登陆的token
-(void)requestWechatLoginToken:(NSString *)authCode
{
    // 通过appid和secret 请求tongken
    NSString *appId = @"wx47f629be8dac75a7";
    NSString *appSecret = @"1d3d3a6f7e540005f44469181a999a28";
    // 发送微信授权码到后端
    NSString *tokenUrl = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/oauth2/access_token?appid=%@&secret=%@&code=%@&grant_type=authorization_code", appId, appSecret, authCode];
    [HttpRequest getReq:tokenUrl parameters:nil completion:^(NSData *data, NSURLResponse *response, NSError *error){
        // 获取的数据转换为json
        NSDictionary* dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        NSLog(@"获取token结果: %@", dict);
        [self requestWechatLoginUserinfo:dict];
    }];
}
// 获取登陆的用户信息
-(void)requestWechatLoginUserinfo:(NSDictionary *)dict
{
    NSString *opendId = dict[@"openid"];
    NSString *accessToken = dict[@"access_token"];
    NSString *userInfoUrl = [NSString stringWithFormat:@"https://api.weixin.qq.com/sns/userinfo?access_token=%@&openid=%@", accessToken, opendId];
    
    [HttpRequest getReq:userInfoUrl parameters:nil completion:^(NSData *data, NSURLResponse *response, NSError *error){
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        
        NSDictionary *result = @{
            @"code" : @(WechatLoginSuccess),
            @"ret" : dict
        };
        [[WechatM wechatM] backResult:result];
        NSLog(@"获取用户信息结果：%@", dict);
    }];
}











@end
