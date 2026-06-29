//
//  YlhAdM.m
//  mjxxl
//
//  Created by 王兴伟 on 2026/1/12.
//  Copyright © 2026 mjxxl. All rights reserved.
//

#import "YlhAdM.h"
#import "GDTMobSDK/GDTSDKConfig.h"
#import "GDTMobSDK/GDTRewardVideoAd.h"

#import "AppTrackingTransparency/AppTrackingTransparency.h"
#import "AdSupport/AdSupport.h"


NS_ASSUME_NONNULL_BEGIN

NSString * const ONADLOAD = @"ONADLOAD";
NSString * const OVERDUE = @"OVERDUE";
NSString * const ONVIDEOCACHED = @"ONVIDEOCACHED";
NSString * const ONNOAD = @"ONNOAD";
NSString * const ONADEXPOSE = @"ONADEXPOSE";
NSString * const ONADCLICK = @"ONADCLICK";
NSString * const ONADCLOSE = @"ONADCLOSE";
NSString * const ONADSHOW = @"ONADSHOW";
NSString * const ONVIDEOCOMPLETE = @"ONVIDEOCOMPLETE";
NSString * const ONREWARD = @"ONREWARD";




@implementation YlhAdM

+ (void)initSDK {
    BOOL result = [GDTSDKConfig initWithAppId: @"1210856217"];
    if(result){ NSLog(@"优量汇SDK初始化成功。"); }
    [GDTSDKConfig startWithCompletionHandler:^(BOOL success, NSError *error) {
        if(success){
            NSLog(@"start with completion handler.");
        }
    }];
}

+ (void)idfa:(BOOL)state {
    [GDTSDKConfig forbiddenIDFA:state];
}

+ (void)channel:(NSInteger)channel {
    [GDTSDKConfig setChannel:channel];
}

+ (instancetype)sharedManager
{
    static YlhAdM *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[YlhAdM alloc] init];
    });
    return instance;
}


- (void)requestAuth:(void (^)(AdAuthorizationStatus status))completion {
    if (@available(iOS 14, *)) {
        // 1. 检查当前的授权状态
        ATTrackingManagerAuthorizationStatus status = [ATTrackingManager trackingAuthorizationStatus];
        __block AdAuthorizationStatus authStatus;
        // 2. 如果状态是“未决定”，才发起请求，避免重复弹窗
        if (status == ATTrackingManagerAuthorizationStatusNotDetermined) {
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
                // 3. 在回调中处理用户的选择
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    switch (status) {
                        case ATTrackingManagerAuthorizationStatusAuthorized:
                            NSLog(@"✅ 用户授权追踪");
                            authStatus = AdAuthorizationStatusAllowed;
                            // 在这里可以初始化依赖IDFA的SDK或进行其他操作
                            break;
                        case ATTrackingManagerAuthorizationStatusDenied:
                            NSLog(@"❌ 用户拒绝追踪");
                            authStatus = AdAuthorizationStatusDenied;
                            // 根据业务逻辑进行降级处理
                            break;
                        default:
                            authStatus = AdAuthorizationStatusDenied;
                            break;
                    }
                    if(completion){
                        completion(authStatus);
                    }
                });
            }];
        } else {
            // 用户已作出选择，可根据现有状态进行相应处理
            NSLog(@"⚠️ 授权状态已确定: %ld", (long)status);
            if(status == ATTrackingManagerAuthorizationStatusAuthorized){
                NSLog(@"✅ 用户授权追踪");
                authStatus = AdAuthorizationStatusAllowed;
            }else if(status == ATTrackingManagerAuthorizationStatusDenied){
                NSLog(@"❌ 用户拒绝追踪");
                authStatus = AdAuthorizationStatusDenied;
            }else{
                authStatus = AdAuthorizationStatusDenied;
            }
            if(completion){ completion(authStatus); }
        }
    } else {
        if(completion){ completion(AdAuthorizationStatusAllowed); }
        // iOS 14 以下的版本无需ATT授权，但需确保没有相关代码
    }
}


/// 初始化激励视频广告
- (void)viewDidLoad
{
    self.rewardVideoAd = [[GDTRewardVideoAd alloc] initWithPlacementId:self.placementId];
    self.rewardVideoAd.delegate = self;
    self.rewardVideoAd.videoMuted = NO;
    [self.rewardVideoAd loadAd];
}


/// 加载视频广告
/// - Parameters:
///   - placementId: <#placementId description#>
///   - completion: <#completion description#>
- (void)loadVideo:(NSString *)placementId completion:(void (^)(NSDictionary *dict))completion
{
    self.placementId = placementId;
    self.videoCompletion = completion;
    
    // 广告没有初始化，初始化广告
    if(!self.rewardVideoAd){
        NSLog(@"ADlogs-初始化广告。");
        [self viewDidLoad];
        return;
    }
    // 广告不可用，加载广告
    if(!self.rewardVideoAd.isAdValid){
        NSLog(@"ADlogs-没有可用的广告，加载广告。");
        [self.rewardVideoAd loadAd];
        return;
    }
    // 通知前端
    [self callClient:ONADLOAD];
}


/// 显示激励视频
- (void)showVideo
{
    UIViewController *rootVc = [UIApplication sharedApplication].keyWindow.rootViewController;
    [self.rewardVideoAd showAdFromRootViewController:rootVc];
}

/// 通知前端
/// - Parameter result: <#result description#>
- (void)callClient:(NSString *)field
{
    NSDictionary *dict = @{ @"status":field };
    if(self.videoCompletion){
        self.videoCompletion(dict);
    }
    NSLog(@"ADlogs-激励视频to client：%@", field);
}







/// 激励视频加载回调
/// - Parameter rewardedVideoAd: <#rewardedVideoAd description#>
- (void)gdt_rewardVideoAdDidLoad:(GDTRewardVideoAd *)rewardedVideoAd
{
    [self callClient:ONADLOAD];
    NSLog(@"ADlogs-视频广告加载成功。");
}

- (void)gdt_rewardVideoAdDidExposed:(GDTRewardVideoAd *)rewardedVideoAd
{
    [self callClient:ONADEXPOSE];
    NSLog(@"ADlogs-视频广告曝光成功。");
}

- (void)gdt_rewardVideoAdDidClicked:(GDTRewardVideoAd *)rewardedVideoAd
{
    [self callClient:ONADCLICK];
    NSLog(@"ADlogs-视频广告点击。");
}

- (void)gdt_rewardVideoAdDidClose:(GDTRewardVideoAd *)rewardedVideoAd
{
    self.rewardVideoAd = nil;
    [self callClient:ONADCLOSE];
    NSLog(@"ADlogs-视频广告关闭。");
}

- (void)gdt_rewardVideoAdWillVisible:(GDTRewardVideoAd *)rewardedVideoAd
{
    [self callClient:ONADSHOW];
    NSLog(@"ADlogs-视频广告展示成功。");
}

- (void)gdt_rewardVideoAdDidPlayFinish:(GDTRewardVideoAd *)rewardedVideoAd
{
    [self callClient:ONVIDEOCOMPLETE];
    NSLog(@"ADlogs-视频广告结束。");
}

- (void)gdt_rewardVideoAdDidRewardEffective:(GDTRewardVideoAd *)rewardedVideoAd
{
    [self callClient:ONREWARD];
    NSLog(@"ADlogs-视频广告获取奖励成功。");
}

/// 激励视频异常
/// - Parameters:
///   - rewardedVideoAd: <#rewardedVideoAd description#>
///   - error: <#error description#>
- (void)gdt_rewardVideoAd:(GDTRewardVideoAd *)rewardedVideoAd didFailWithError:(NSError *)error
{
    if (error.code == 4014) {
        NSLog(@"ADlogs-请拉取到广告后再调用展示接口");
        [self callClient:ONNOAD];
    } else if (error.code == 4016) {
        NSLog(@"ADlogs-应用方向与广告位支持方向不一致");
    } else if (error.code == 5012) {
        NSLog(@"ADlogs-广告已过期");
        [self callClient:OVERDUE];
    } else if (error.code == 4015) {
        NSLog(@"ADlogs-广告已经播放过，请重新拉取");
        [self callClient:ONVIDEOCACHED];
    } else if (error.code == 5002) {
        NSLog(@"ADlogs-视频下载失败");
        [self callClient:ONNOAD];
    } else if (error.code == 5003) {
        NSLog(@"ADlogs-视频播放失败");
    } else if (error.code == 5004) {
        NSLog(@"ADlogs-没有合适的广告");
        [self callClient:ONNOAD];
    }
    NSLog(@"ADlogs-ERROR: %@", error);
}


@end



NS_ASSUME_NONNULL_END
