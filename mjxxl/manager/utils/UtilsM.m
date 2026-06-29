//
//  UtilsM.m
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/26.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import "UtilsM.h"
#import "UIKit/UIKit.h"
#import "AudioToolbox/AudioToolbox.h"
#import "AVFoundation/AVFoundation.h"

NS_ASSUME_NONNULL_BEGIN

static dispatch_source_t timer = NULL;
static BOOL active = NO;
// 播放相关静态变量
static AVPlayer *_currentPlayer = nil;
static void (^_currentCompletion)(NSDictionary *) = nil;

NSString * const ListenNamePause = @"pause";// 切换到后台
NSString * const ListenNameResume = @"resume"; // 切换到前台

static UIBackgroundTaskIdentifier _bgTask;
static BOOL _shouldCancelBackgroundTask = NO;

static ListenBlock listenCompletion = nil;// 监听回调

@implementation UtilsM

+ (void)initialize{
    if (self == [UtilsM class]) {
        _bgTask = UIBackgroundTaskInvalid;
        // 监听应用进入后台
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationDidEnterBackground:)
                                                     name:UIApplicationDidEnterBackgroundNotification
                                                   object:nil];
        // 监听应用即将进入前台
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
}

// 全局监听
+ (void)setListener:(ListenBlock)completion {
    listenCompletion = completion;
}
// 切换到后台
+ (void)applicationDidEnterBackground:(NSNotification *)notification {
//    [[NSNotificationCenter defaultCenter] postNotificationName:ListenNamePause object:nil];
    if(listenCompletion){ listenCompletion(ListenNamePause); }
//    
//    // 如果已有后台任务，先结束（理论上不会发生，但安全起见）
//    if (_bgTask != UIBackgroundTaskInvalid) {
//        [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
//        _bgTask = UIBackgroundTaskInvalid;
//    }
//    
//    _shouldCancelBackgroundTask = NO;// 重置取消标志
//        
//    UIApplication *app = [UIApplication sharedApplication];
//    __block UIBackgroundTaskIdentifier localTask = [app beginBackgroundTaskWithExpirationHandler:^{
//        // 时间用尽，强制结束
//        if (_bgTask != UIBackgroundTaskInvalid) {
//            [app endBackgroundTask:_bgTask];
//            _bgTask = UIBackgroundTaskInvalid;
//            NSLog(@">>>>> background task expired");
//        }
//    }];
//    _bgTask = localTask;
//        
//    // 使用 dispatch_after 延迟执行，而不是 sleep
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(60.0 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//        // 检查是否已被前台取消
//        if (_shouldCancelBackgroundTask) {
//            NSLog(@">>>>> background task cancelled by foreground");
//            return;
//        }
//        // 操作完成后，结束后台任务
//        if (_bgTask != UIBackgroundTaskInvalid) {
//            [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
//            _bgTask = UIBackgroundTaskInvalid;
//            NSLog(@">>>>> background task ended normally");
//        }
//    });
}

+ (void)applicationWillEnterForeground:(NSNotification *)notification {
//    // 设置取消标志，让后台 block 不再执行
//    _shouldCancelBackgroundTask = YES;
//    // 如果后台任务还在，立即结束
//    if (_bgTask != UIBackgroundTaskInvalid) {
//        [[UIApplication sharedApplication] endBackgroundTask:_bgTask];
//        _bgTask = UIBackgroundTaskInvalid;
//        NSLog(@">>>>> background task cancelled due to foreground");
//    }
//    
    if(listenCompletion){ listenCompletion(ListenNameResume); }
}


/// 获取屏幕方向
+ (Orientation)getOrientation {
    if(UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)){
        return OrientationLandscape;
    }else if(UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation)){
        return OrientationPortrait;
    }
    return OrientationPortrait;
}


/// 获取安全区域数据
+ (UIEdgeInsets)getSafeInsets {
    UIWindow  *window = [UIApplication sharedApplication].keyWindow;
    if(!window){
        window = [[UIApplication sharedApplication].windows firstObject];
    }
    if(@available(iOS 11.0, *)){
        return window.safeAreaInsets;
    }
    return UIEdgeInsetsZero;
}

/// 获取安全区域
+ (CGFloat)getStatusBarHeight {
    if([self getOrientation] == OrientationLandscape){
        return [self getSafeInsets].left;
    }else{
        return [self getSafeInsets].top;
    }
}


/// 获取屏幕宽高
+ (NSDictionary *)getScreenInfo {
    CGFloat width = [UIScreen mainScreen].bounds.size.width;
    CGFloat height = [UIScreen mainScreen].bounds.size.height;
    
    CGFloat screenWidth = width;
    CGFloat screenHeight = height;
    CGFloat statusBarHeight = [self getStatusBarHeight];
    if([self getOrientation] == OrientationLandscape){
        screenWidth = MAX(width, height);
        screenHeight = MIN(width, height);
    }else{
        screenWidth = MIN(width, height);
        screenHeight = MAX(width, height);
    }
    
    NSDictionary *info = @{ @"width":@(screenWidth),@"height":@(screenHeight),@"statusBarHeight":@(statusBarHeight) };
    return info;
}


/// 打开应用商店
/// - Parameter url: <#url description#>
+ (void)openAppStore:(NSString *)url
{
    // 构造 App Store 跳转链接（iOS 10+ 推荐格式）
    NSURL *appStoreURL = [NSURL URLWithString:url];

    // 打开链接
    if ([[UIApplication sharedApplication] canOpenURL:appStoreURL]) {
        [[UIApplication sharedApplication] openURL:appStoreURL options:@{} completionHandler:nil];
    }
}

/// 重启
+ (void)rebootApp{}


/// 关闭 （别瞎搞，据说审核会被拒）
+ (void)closeApp{
//    exit(0); // 强烈不推荐
    UIApplication *app = [UIApplication sharedApplication];
    [app performSelector:@selector(suspend)];// 直接退出到后台
}

/// 短震动
+ (void)vibrateShort{
    if(@available(iOS 10.0, *)){
        UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleHeavy];
        [generator prepare];
        [generator impactOccurred];
    }else{
        
    }
}

/// 长震动
+ (void)vibrateLong{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

/// 播放网络音频
+ (void)playVoice:(NSString *)url completion:(nonnull void (^)(NSDictionary * _Nonnull))completion {
    // 1. 参数校验
    if (!url || url.length == 0) {
        if (completion) completion(@{@"status": @NO, @"msg": @"URL为空"});
        return;
    }
    NSURL *audioURL = [NSURL URLWithString:url];
    if (!audioURL) {
        if (completion) completion(@{@"status": @NO, @"msg": @"无效的URL"});
        return;
    }

    // 2. 停止并清理上一个播放任务
    [self stopCurrentPlayback];

    // 3. 保存新的 completion
    _currentCompletion = [completion copy];

    // 4. 创建播放器并开始播放
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:audioURL];
    _currentPlayer = [AVPlayer playerWithPlayerItem:item];

    // 5. 监听播放结束
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlaybackFinished:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:item];

    // 6. 监听播放失败（可选，增强健壮性）
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlaybackFailed:)
                                                 name:AVPlayerItemFailedToPlayToEndTimeNotification
                                               object:item];

    [_currentPlayer play];
}

// 停止当前播放并清理资源
+ (void)stopCurrentPlayback {
    if (_currentPlayer) {
        // 移除通知观察者
        AVPlayerItem *currentItem = _currentPlayer.currentItem;
        if (currentItem) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:currentItem];
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                          object:currentItem];
        }
        [_currentPlayer pause];
        _currentPlayer = nil;
    }
    _currentCompletion = nil;
}

// 播放完成回调
+ (void)onPlaybackFinished:(NSNotification *)notification {
    AVPlayerItem *item = notification.object;
    [self finishPlaybackWithItem:item success:YES message:@"播放完成"];
}

// 播放失败回调
+ (void)onPlaybackFailed:(NSNotification *)notification {
    AVPlayerItem *item = notification.object;
    [self finishPlaybackWithItem:item success:NO message:@"播放失败"];
}

// 统一结束处理
+ (void)finishPlaybackWithItem:(AVPlayerItem *)item success:(BOOL)success message:(NSString *)message {
    if (_currentCompletion) {
        NSDictionary *result = @{
            @"status": @(success),
            @"msg": message ?: (success ? @"播放完成" : @"播放出错")
        };
        _currentCompletion(result);
        _currentCompletion = nil;
    }

    // 清理观察者
    if (item) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:item];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemFailedToPlayToEndTimeNotification
                                                      object:item];
    }

    _currentPlayer = nil;
}

/// 获取 Keychain 的 serviceName（自动使用 Bundle ID）
+ (NSString *)keychainServiceName {
    return [[NSBundle mainBundle] bundleIdentifier] ?: @"com.mjxxl.deviceUUID";
}

/// 获取设备唯一标识
+ (NSString *)getDeviceUUID {
    NSString *serviceName = [self keychainServiceName];
    NSString *accountName = @"deviceUUID";
    
    // 1. 先从 Keychain 读取
    NSString *existingUUID = [self loadFromKeychainWithService:serviceName account:accountName];
    if (existingUUID) {
        return existingUUID;
    }
    
    // 2. 如果 Keychain 中没有，生成新的 UUID
    NSString *newUUID = [self generateDeviceUUID];
    
    // 3. 保存到 Keychain
    [self saveToKeychainWithService:serviceName account:accountName uuid:newUUID];
    
    return newUUID;
}

/// 清除设备标识
+ (void)clearDeviceUUID {
    NSString *serviceName = [self keychainServiceName];
    NSString *accountName = @"deviceUUID";
    
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: serviceName,
        (__bridge id)kSecAttrAccount: accountName
    };
    
    SecItemDelete((__bridge CFDictionaryRef)query);
}

#pragma mark - Private Methods (设备标识)

/// 生成设备 UUID（优先使用 IDFV，失败则生成随机 UUID）
+ (NSString *)generateDeviceUUID {
    NSString *idfv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return idfv ?: [[NSUUID UUID] UUIDString];
}

/// 从 Keychain 读取 UUID
+ (NSString *)loadFromKeychainWithService:(NSString *)service account:(NSString *)account {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    
    if (status == errSecSuccess && result != NULL) {
        NSData *data = (__bridge_transfer NSData *)result;
        NSString *uuid = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return uuid;
    }
    
    return nil;
}

/// 保存 UUID 到 Keychain
+ (void)saveToKeychainWithService:(NSString *)service account:(NSString *)account uuid:(NSString *)uuid {
    NSData *data = [uuid dataUsingEncoding:NSUTF8StringEncoding];
    if (!data) return;
    
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: service,
        (__bridge id)kSecAttrAccount: account,
        (__bridge id)kSecValueData: data
    };
    
    // 先删除旧的（如果有）
    SecItemDelete((__bridge CFDictionaryRef)query);
    // 再添加新的
    SecItemAdd((__bridge CFDictionaryRef)query, NULL);
}

// ========================================================

@end

NS_ASSUME_NONNULL_END


