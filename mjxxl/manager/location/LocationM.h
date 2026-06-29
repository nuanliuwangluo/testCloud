//
//  locationM.h
//  mjxxl
//
//  Created by 王兴伟 on 2026/3/24.
//  Copyright © 2026 mjxxl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, LocationAuthorizationStatus){
    LocationAuthorizationStatusNotDetermined = 0,// 未决定
    LocationAuthorizationStatusAuthorized = 1,// 已授权
    LocationAuthorizationStatusDenied = -1, //已拒绝
    LocationAuthorizationStatusRestricted = -2, // 受限制
    LocationAuthorizationStatusDisabled = -3 // 系统定位服务为开启
};

@interface LocationM : NSObject<CLLocationManagerDelegate>

@property (nonatomic, copy, nullable) void (^completionBlock)(NSDictionary *dict);

+ (instancetype)locationM;

- (void)getAuth:(void(^)(LocationAuthorizationStatus status))completion;

- (NSString *)getAuthDes:(LocationAuthorizationStatus)status;

- (void)requestAuth;

- (void)getLocation;

@end

NS_ASSUME_NONNULL_END
