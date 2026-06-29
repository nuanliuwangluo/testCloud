//
//  YlhAdM.h
//  mjxxl
//
//  Created by 王兴伟 on 2026/1/12.
//  Copyright © 2026 mjxxl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GDTMobSDK/GDTRewardVideoAd.h"

NS_ASSUME_NONNULL_BEGIN

@interface YlhAdM : NSObject<GDTRewardedVideoAdDelegate>
@property (nonatomic, strong, nullable)GDTRewardVideoAd *rewardVideoAd;
@property (nonatomic, copy)NSString *placementId;

@property (nonatomic, copy, nullable) void (^videoCompletion)(NSDictionary *dict);

typedef NS_ENUM(NSInteger, AdAuthorizationStatus){
    AdAuthorizationStatusAllowed = 1,
    AdAuthorizationStatusDenied
};

+ (instancetype)sharedManager;

+ (void)initSDK;

+ (void)idfa:(BOOL)state;

+ (void)channel:(NSInteger)channel;

- (void)loadVideo:(NSString *)placementId completion:(void (^)(NSDictionary *dict))completion;

- (void)showVideo;

- (void)requestAuth:(void(^)(AdAuthorizationStatus status))completion;

@end

NS_ASSUME_NONNULL_END
