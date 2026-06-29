//
//  ALAdManager.h
//  17hymjxxl
//
//  Created by 王兴伟 on 2026/1/12.
//  Copyright © 2026 17hymjxxl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppLovinSDK/AppLovinSDK.h> // 导入 AppLovin SDK

NS_ASSUME_NONNULL_BEGIN

// 定义回调状态常量，与优量汇保持一致
extern NSString * const AL_ONADLOAD;       // 广告加载成功
extern NSString * const AL_ONNOAD;         // 无广告
extern NSString * const AL_OVERDUE;        // 广告过期
extern NSString * const AL_ONVIDEOCACHED;  // 视频缓存完成 (AppLovin 中通常加载即缓存)
extern NSString * const AL_ONADSHOW;       // 广告展示
extern NSString * const AL_ONADEXPOSE;     // 广告曝光 (与展示类似)
extern NSString * const AL_ONADCLICK;      // 广告被点击
extern NSString * const AL_ONVIDEOCOMPLETE;// 视频播放完毕 (关键奖励点)
extern NSString * const AL_ONREWARD;       // 用户获得奖励 (与视频完成通常同时)
extern NSString * const AL_ONADCLOSE;      // 广告关闭

@interface ALAdM : NSObject <MARewardedAdDelegate>

// 单例
+ (instancetype)sharedManager;

// 加载激励视频广告 (传入你在 AppLovin 后台创建的 Ad Unit ID)
- (void)loadVideo:(NSString *)adUnitId completion:(void (^)(NSDictionary *dict))completion;

// 展示激励视频广告
- (void)showVideo;

// 请求 ATT 授权 (iOS 14+)
- (void)requestAuth:(void(^)(BOOL isAuthorized))completion;

@end

NS_ASSUME_NONNULL_END
