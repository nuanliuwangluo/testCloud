//
//  UtilsM.h
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/26.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UtilsM : NSObject

typedef NS_ENUM(NSInteger, Orientation){
    OrientationLandscape = 1,// 横屏
    OrientationPortrait = 2 // 竖屏
};

typedef void (^ListenBlock)(NSString *name);// 监听回调

+ (void)setListener:(ListenBlock)completion;

+ (Orientation)getOrientation;

+ (UIEdgeInsets)getSafeInsets;

+ (CGFloat)getStatusBarHeight;

+ (NSDictionary *)getScreenInfo;

+ (void)openAppStore:(NSString *)url;

+ (void)rebootApp;

+ (void)closeApp;

+ (void)vibrateShort;

+ (void)vibrateLong;

+ (void)playVoice:(NSString *)url completion:(void (^)(NSDictionary *dict))completion;

/// 获取设备唯一标识（卸载重装后保持不变，存储在 Keychain 中）
+ (NSString *)getDeviceUUID;

/// 清除设备标识（一般用于测试或用户登出场景）
+ (void)clearDeviceUUID;

@end

NS_ASSUME_NONNULL_END
