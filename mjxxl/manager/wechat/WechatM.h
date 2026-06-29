//
//  WechatM.h
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/8.
//  Copyright © 2025 mjxxl. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "WXApi.h"

NS_ASSUME_NONNULL_BEGIN

@interface WechatM : NSObject <WXApiDelegate>

@property (nonatomic, copy, nullable) void (^loginHandler)(NSDictionary *dict);

typedef NS_ENUM(NSInteger, WechatLoginError){
    WechatLoginSuccess = 0,// 登陆成功
    WechatAuthDenied = -1,// 授权失败
    WechatLoginDenied = -2,// 登陆失败
    WechatNotInstalled = -3, // 未安装
};

typedef NS_ENUM(NSInteger, WechatScene){
    WechatSceneSession = 0,// 会话
    WechatSceneTimeline = 1 // 朋友圈
};

typedef NS_ENUM(NSInteger, WechatMiniProgramType){
    WechatMiniProgramRealease = 0,// 正式版
    WechatMiniProgramDevelopment = 1,// 开发版
    WechatMiniProgramPreview = 2 // 体验版
};

+ (instancetype)wechatM;

// 检查微信是否安装
- (BOOL)isWechatInstalled;

// 发起微信登录
- (void)login;

// 分享给好友
- (void)shareToFriend:(NSDictionary *)dict completion:(void (^)(NSDictionary *dict))completion;

// 分享文本内容好友
- (void)shareTxtToFriend:(NSString *)text completion:(void (^)(NSDictionary *dict))completion;

// 分享图片给好友
- (void)shareScreenshotToFriend:(void (^)(NSDictionary *dict))completion;

// 分享小程序
- (void)shareMiniProgram:(NSDictionary *)dict completion:(void (^)(NSDictionary *dict))completion;

// 处理微信回调URL
- (BOOL)handleWechatOpenURL:(NSURL *)url;

// 回调函数
- (void)backResult:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
