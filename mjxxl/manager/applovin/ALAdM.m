//
//  ALAdManager.m
//  17hymjxxl
//
//  Created by 王兴伟 on 2026/1/12.
//  Copyright © 2026 17hymjxxl. All rights reserved.
//

#import "ALAdM.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <AdSupport/AdSupport.h>

// 定义回调状态常量
NSString * const AL_ONADLOAD = @"ONADLOAD";
NSString * const AL_ONNOAD = @"ONNOAD";
NSString * const AL_OVERDUE = @"OVERDUE";
NSString * const AL_ONVIDEOCACHED = @"ONVIDEOCACHED";
NSString * const AL_ONADSHOW = @"ONADSHOW";
NSString * const AL_ONADEXPOSE = @"ONADEXPOSE";
NSString * const AL_ONADCLICK = @"ONADCLICK";
NSString * const AL_ONVIDEOCOMPLETE = @"ONVIDEOCOMPLETE";
NSString * const AL_ONREWARD = @"ONREWARD";
NSString * const AL_ONADCLOSE = @"ONADCLOSE";

@interface ALAdM ()

@property (nonatomic, strong) MARewardedAd *rewardedAd;   // AppLovin 激励广告对象
@property (nonatomic, copy) NSString *currentAdUnitId;    // 当前广告单元 ID
@property (nonatomic, copy) void (^videoCompletion)(NSDictionary *dict); // 回调 block
@property (nonatomic, assign) BOOL hasRewarded;           // 标记是否已发放奖励，防止重复

@end

@implementation ALAdM

#pragma mark - 单例
+ (instancetype)sharedManager {
    static ALAdM *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ALAdM alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 可以在这里做一些额外的初始化
    }
    return self;
}

#pragma mark - 加载广告
- (void)loadVideo:(NSString *)adUnitId completion:(void (^)(NSDictionary *dict))completion {
    // 1. 保存参数
    self.currentAdUnitId = adUnitId;
    self.videoCompletion = completion;
    self.hasRewarded = NO; // 重置奖励标记
    
    // 2. 初始化或复用激励视频对象
    if (!self.rewardedAd || ![self.rewardedAd.adUnitIdentifier isEqualToString:adUnitId]) {
        // 如果广告对象不存在或广告单元 ID 变了，重新创建
        self.rewardedAd = [MARewardedAd sharedWithAdUnitIdentifier:adUnitId];
        self.rewardedAd.delegate = self; // 设置代理，接收广告事件
    }
    
    // 3. 检查广告是否已加载且有效
    if (self.rewardedAd.isReady) {
        // 广告已就绪，直接回调加载成功
        [self callClient:AL_ONADLOAD withExtra:nil];
        return;
    }
    
    // 4. 加载广告
    [self.rewardedAd loadAd];
    
    // 注意：加载结果会在代理方法中回调
    // 用户可能会在短时间内多次调用，避免重复加载？SDK内部会处理
}

#pragma mark - 展示广告
- (void)showVideo {
    if (self.rewardedAd && self.rewardedAd.isReady) {
        // 获取当前顶层控制器用于展示广告
//        UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
//        UIViewController *topVC = [self topViewControllerFrom:rootVC];
        
        // 展示广告，并传入展示完成的回调
        [self.rewardedAd showAd];
    } else {
        // 广告未准备好，通知前端
        [self callClient:AL_ONNOAD withExtra:@{@"reason": @"广告未准备好"}];
        NSLog(@"ADlogs-AppLovin 广告未准备好，无法展示");
    }
}

#pragma mark - ATT 授权请求
- (void)requestAuth:(void(^)(BOOL isAuthorized))completion {
    if (@available(iOS 14, *)) {
        ATTrackingManagerAuthorizationStatus status = [ATTrackingManager trackingAuthorizationStatus];
        if (status == ATTrackingManagerAuthorizationStatusNotDetermined) {
            [ATTrackingManager requestTrackingAuthorizationWithCompletionHandler:^(ATTrackingManagerAuthorizationStatus status) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    BOOL authorized = (status == ATTrackingManagerAuthorizationStatusAuthorized);
                    if (completion) completion(authorized);
                });
            }];
        } else {
            BOOL authorized = (status == ATTrackingManagerAuthorizationStatusAuthorized);
            if (completion) completion(authorized);
        }
    } else {
        if (completion) completion(YES); // iOS 14 以下视为已授权
    }
}

#pragma mark - MARewardedAdDelegate (核心代理方法)

/// 广告加载成功
- (void)didLoadAd:(MAAd *)ad {
    NSLog(@"ADlogs-AppLovin 激励视频加载成功");
    [self callClient:AL_ONADLOAD withExtra:nil];
    // 注意：加载成功不代表视频已缓存完毕，但 AppLovin 通常加载即就绪
    // 可以额外通知视频缓存完成
    [self callClient:AL_ONVIDEOCACHED withExtra:nil];
}

/// 广告加载失败
- (void)didFailToLoadAdForAdUnitIdentifier:(NSString *)adUnitIdentifier withError:(MAError *)error {
    NSLog(@"ADlogs-AppLovin 激励视频加载失败: %@", error);
    // 错误码可以参考 AppLovin 文档
    NSString *status = AL_ONNOAD;
    if (error.code == 204) { // 204 通常表示无广告填充
        status = AL_ONNOAD;
    }
    [self callClient:status withExtra:@{@"error": error.message ?: @"加载失败"}];
}

/// 广告展示成功 (视频开始播放)
- (void)didDisplayAd:(MAAd *)ad {
    NSLog(@"ADlogs-AppLovin 激励视频开始展示");
    [self callClient:AL_ONADSHOW withExtra:nil];
    [self callClient:AL_ONADEXPOSE withExtra:nil]; // 曝光通常伴随展示
}

/// 广告展示失败
- (void)didFailToDisplayAd:(MAAd *)ad withError:(MAError *)error {
    NSLog(@"ADlogs-AppLovin 激励视频展示失败: %@", error);
    [self callClient:AL_ONNOAD withExtra:@{@"error": error.message ?: @"展示失败"}];
}

/// 广告点击
- (void)didClickAd:(MAAd *)ad {
    NSLog(@"ADlogs-AppLovin 激励视频被点击");
    [self callClient:AL_ONADCLICK withExtra:nil];
}

/// 广告关闭 (用户主动关闭或视频结束自动关闭)
- (void)didHideAd:(MAAd *)ad {
    NSLog(@"ADlogs-AppLovin 激励视频关闭");
    [self callClient:AL_ONADCLOSE withExtra:nil];
    
    // 重要：广告关闭后，可以在此处准备下一次加载
    // 但注意：如果用户获得奖励，不要再重复加载影响体验
}

/// 视频播放完毕 (关键奖励点)
- (void)didCompleteRewardedVideo:(MAAd *)ad {
    NSLog(@"ADlogs-AppLovin 激励视频播放完毕");
    [self callClient:AL_ONVIDEOCOMPLETE withExtra:nil];
    
    // 注意：视频播放完毕不直接等同于给予奖励，
    // 必须等待服务器验证回调 `didRewardUserForAd:`
    // 或根据业务逻辑在视频完播时给予奖励
}

/// 用户获得奖励 (服务器验证或客户端验证)
- (void)didRewardUserForAd:(MAAd *)ad withReward:(MAReward *)reward {
    NSLog(@"ADlogs-AppLovin 用户获得奖励: %@", reward.label);
    
    // 防止重复发放奖励 (如果同一个广告实例多次触发)
    if (self.hasRewarded) {
        NSLog(@"ADlogs-奖励已发放，忽略重复回调");
        return;
    }
    self.hasRewarded = YES;
    
    // 通知前端用户获得奖励
    [self callClient:AL_ONREWARD withExtra:@{@"reward": reward.label ?: @"", @"amount": @(reward.amount)}];
}

#pragma mark - 辅助方法

/// 通知前端 (统一回调)
- (void)callClient:(NSString *)status withExtra:(NSDictionary * _Nullable)extra {
    if (self.videoCompletion) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:@{@"status": status}];
        if (extra) {
            [dict addEntriesFromDictionary:extra];
        }
        self.videoCompletion([dict copy]);
    }
    NSLog(@"ADlogs-AppLovin 回调前端: %@", status);
}

/// 获取当前顶层 ViewController
- (UIViewController *)topViewControllerFrom:(UIViewController *)rootVC {
    if ([rootVC isKindOfClass:[UINavigationController class]]) {
        return [self topViewControllerFrom:[(UINavigationController *)rootVC topViewController]];
    } else if ([rootVC isKindOfClass:[UITabBarController class]]) {
        return [self topViewControllerFrom:[(UITabBarController *)rootVC selectedViewController]];
    } else if (rootVC.presentedViewController) {
        return [self topViewControllerFrom:rootVC.presentedViewController];
    }
    return rootVC;
}

@end
