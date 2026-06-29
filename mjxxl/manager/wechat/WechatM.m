//
//  WechatM.m
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/8.
//  Copyright © 2025 mjxxl. All rights reserved.
//


#import "WechatM.h"
#import "HttpRequest.h"

@implementation WechatM

+ (instancetype)wechatM {
    static WechatM *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WechatM alloc] init];
    });
    return instance;
}

- (BOOL)isWechatInstalled {
    // 检查微信是否安装
    if (![WXApi isWXAppInstalled]) {
        NSLog(@"未安装微信客户端");
        NSDictionary *dict = @{
            @"code":@(WechatNotInstalled),
            @"msg":@"未安装微信客户端"
        };
        [self backResult:dict];
        return false;
    }
    return true;
}

- (void)login {
    // 检查微信是否安装
    if([self isWechatInstalled]){
        // 创建授权请求
        SendAuthReq *authReq = [[SendAuthReq alloc] init];
        authReq.scope = @"snsapi_userinfo";
        authReq.state = @"wechat_mjxxl_auth_2025";
        // 发送授权请求
        [WXApi sendReq:authReq completion:^(BOOL success) {
            if (success) {
                NSLog(@"微信登录请求发送成功");
            } else {
                NSLog(@"微信登录请求发送失败");
            }
        }];
    }
}

// 分享链接
- (void)shareToFriend:(NSDictionary *)dict completion:(void (^)(NSDictionary *dict))completion
{
    if([self isWechatInstalled]){
        WXMediaMessage *message = [WXMediaMessage message];
        message.title = dict[@"title"];
        message.description = dict[@"desc"];
        if(dict[@"thumb"]){
            UIImage *thumb = [UIImage imageNamed:dict[@"thumb"]];
            UIImage *compressedThumb = [self compressedImage:thumb toByte:32 * 1024];
            [message setThumbImage:compressedThumb];
        }
        
        WXWebpageObject *wwpo = [WXWebpageObject object];
        wwpo.webpageUrl = dict[@"url"];
        message.mediaObject = wwpo;
        
        SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
        req.message = message;
        req.scene = WechatSceneSession;
        [WXApi sendReq:req completion:^(BOOL success) {
            NSDictionary *result = @{ @"code" : @"0" };
            completion(result);
        }];
    }
}

// 分享一段文本
- (void)shareTxtToFriend:(NSString *)text completion:(void (^)(NSDictionary * dict))completion
{
    if([self isWechatInstalled]){
        SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
        req.text = text;
        req.bText = YES;
        req.scene = WechatSceneSession;
        [WXApi sendReq:req completion:^(BOOL success) {
            NSDictionary *result = @{ @"code" : @"0" };
            completion(result);
        }];
    }
}

// 分享截屏
- (void)shareScreenshotToFriend:(void (^)(NSDictionary *))completion
{
    if([self isWechatInstalled]){
        UIImage *screenshot = [self captureFullScreen];
        
        WXMediaMessage *message = [WXMediaMessage message];
        WXImageObject *imageObject = [WXImageObject object];
        imageObject.imageData = UIImageJPEGRepresentation(screenshot, 0.9);
        message.mediaObject = imageObject;
        
        SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
        req.message = message;
        req.scene = WechatSceneSession;
        [WXApi sendReq:req completion:^(BOOL success) {
            NSDictionary *result = @{ @"code" : @"0" };
            completion(result);
        }];
    }
}

// 分享小程序
- (void)shareMiniProgram:(NSDictionary *)dict completion:(void (^)(NSDictionary *dict))completion
{
    if([self isWechatInstalled]){
        WXMiniProgramObject *miniObject = [WXMiniProgramObject object];
        miniObject.webpageUrl = @"https://www.weixin.com";
        miniObject.miniProgramType = [self stringToMiniType:dict[@"type"]];
        miniObject.userName = dict[@"userName"];
        miniObject.path = dict[@"path"];
        miniObject.withShareTicket = (BOOL)dict[@"withShareTicket"];
        miniObject.isUpdatableMessage = (BOOL)dict[@"isUpdatebleMessage"];
        
        WXMediaMessage *message = [WXMediaMessage message];
        message.title = dict[@"title"];
        message.description = dict[@"desc"];
        if(dict[@"thumb"]){
            UIImage *thumb = [UIImage imageNamed:dict[@"thumb"]];
            UIImage *compressedThumb = [self compressedImage:thumb toByte:32 * 1024];
            [message setThumbImage:compressedThumb];
        }
        message.mediaObject = miniObject;
        
        SendMessageToWXReq *req = [[SendMessageToWXReq alloc] init];
        req.message = message;
        req.scene = WechatSceneSession;
        req.bText = NO;
        [WXApi sendReq:req completion:^(BOOL success) {
            NSDictionary *result = @{ @"code" : @"0" };
            completion(result);
        }];
    }
}

// 字符串强转成 WXMiniProgramType 类型
- (WXMiniProgramType)stringToMiniType:(NSString *)string
{
    // 体验版
    if([string isEqualToString:@"preview"]){
        return WXMiniProgramTypePreview;
    }
    // 开发版
    else if([string isEqualToString:@"development"]){
        return WXMiniProgramTypeTest;
    }
    // 发布版
    else if([string isEqualToString:@"release"]){
        return WXMiniProgramTypeRelease;
    }
    else{
        return WXMiniProgramTypeRelease;
    }
}


// 截屏
- (UIImage *)captureFullScreen
{
    UIWindow *window = [UIApplication sharedApplication].keyWindow;
    
    UIGraphicsBeginImageContextWithOptions(window.bounds.size, NO, 0.0);
    
    [window drawViewHierarchyInRect:window.bounds afterScreenUpdates:YES];
    
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    NSLog(@"截屏成功，尺寸：%@", NSStringFromCGSize(screenshot.size));
    return screenshot;
}

// 压缩图片
- (UIImage *)compressedImage:(UIImage *)image toByte:(NSInteger)size
{
    CGFloat compression = 0.9f;
    NSData *data = UIImageJPEGRepresentation(image, compression);
    while (data.length > size && compression > 0.1) {
        compression -= 0.1;
        data = UIImageJPEGRepresentation(image, compression);
    }
    return [UIImage imageWithData:data];
}


- (BOOL)handleWechatOpenURL:(NSURL *)url {
    return [WXApi handleOpenURL:url delegate:self];
}


- (void)backResult:(NSDictionary *)dict{
    if(self.loginHandler && dict){
        self.loginHandler(dict);
    }
}




@end
