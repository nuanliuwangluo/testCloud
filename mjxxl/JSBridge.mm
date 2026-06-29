#import "JSBridge.h"
#import "AppDelegate.h"
#import "conchRuntime.h"
#import "WechatM.h"
#import "ClipboardM.h"
#import "AppleLoginM.h"
#import "IapM.h"
#import "UmengM.h"
#import "UtilsM.h"
#import "YlhAdM.h"
#import "ALAdM.h"
#import "ViewController.h"
#import "LocationM.h"
#import "HttpRequest.h"
#import "RecorderM.h"

/**
 *      需要注意的是 如果启动页是手动关闭     前端需要调用  if(window.loadingView)loadingView.hideLoadingView();  关闭启动页面
 */

@implementation JSBridge

+(void)hideSplash
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        [appDelegate.launchView hide];
    });
}
+(void)setTips:(NSArray*)tips
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        appDelegate.launchView.tips = tips;
    });
}
+(void)setFontColor:(NSString*)color
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        [appDelegate.launchView setFontColor:color];
    });
}
+(void)bgColor:(NSString*)color
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        [appDelegate.launchView setBackgroundColor:color];
    });
}
+(void)loading:(NSNumber*)percent
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        [appDelegate.launchView setPercent:percent.integerValue];
    });
}
+(void)showTextInfo:(NSNumber*)show
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        [appDelegate.launchView showTextInfo:show.intValue > 0];
    });
}

// 全局监听一些原生事件
+ (void)listener:(NSString *)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [UtilsM setListener:^(NSString * name) {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"name":name} options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSLog(@"监听到全局消息：%@", name);
            [[conchRuntime GetIOSConchRuntime]callbackToJSWithClass:self.class methodName:@"listener:" ret:jsonString];
        }];
    });
}

// 苹果登陆
// 返回数据格式 { code, email, identityToken, fullName, userId, msg }
+ (void)appleLogin:(NSString*)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [AppleLoginM appleLoginM].loginHandler = ^(NSDictionary * dict){
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSLog(@"授权结果：%@", jsonStr);
            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self.class methodName:@"appleLogin:" ret:jsonStr];
        };
        [[AppleLoginM appleLoginM] login];
    });
}

// 微信登陆
// 返回数据格式 { code, ret:{ openid, city, country, nickname, privilege, language, headimgurl, unionid, sex, province } }
+(void)wxLogin:(NSString*)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // 发起微信登录
        [WechatM wechatM].loginHandler = ^(NSDictionary *dict){
            if(dict){
                NSError* error = nil;
                NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
                NSString* jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self.class methodName:@"wxLogin:" ret:jsonStr];
            }
        };
        [[WechatM wechatM] login];
    });
}


/// 链接分享
/// - Parameter json: { @titl(标题), @desc(描述),  @url(链接地址), @thumb(缩略图名称) }
+ (void)wxShare:(NSString *)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *data = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        NSLog(@"前端参数：%@", dict);
        [[WechatM wechatM] shareToFriend:dict completion:^(NSDictionary * dict) {
            NSError* error = nil;
            NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self.class methodName:@"wxShare:" ret:jsonStr];
        }];
    });
}


/// 分享一个文本
/// - Parameter json: json 直接分享
+ (void)wxShareTxt:(NSString *)text
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WechatM wechatM] shareTxtToFriend:text completion:^(NSDictionary * dict) {
            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self.class methodName:@"wxShareTxt:" ret:dict];
        }];
    });
}


/// 截屏分享
/// - Parameter json: 这个参数其实没有意义，因为该方法本身会处理截屏，压缩资源，分享
+ (void)wxShareScreenshot:(NSString *)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[WechatM wechatM] shareScreenshotToFriend:^(NSDictionary *dict) {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self.class methodName:@"wxShareScreenshot:" ret:jsonStr];
        }];
    });
}

/// 分享小程序
/// - Parameter json:  @title(标题),@desc(描述),@userName(小程序原始id),@thumb(缩略图名称),@path(路径参数),@type(类型:release, development, preview),@withShareTicket(是否携带ticket)
+ (void)wxShareMiniProgram:(NSString *)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
        
        [[WechatM wechatM] shareMiniProgram:dict completion:^(NSDictionary * dict) {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self.class methodName:@"wxShareMiniProgram:" ret:jsonStr];
        }];
    });
}


/// 设置剪切板内容
/// - Parameter text: 要复制到剪切板的文字
+ (NSNumber *)copyToClipboard:(NSString *)text
{
    NSString *content = nil;
    // 1. 判断是否是合法的 NSString 对象
    if ([text isKindOfClass:[NSString class]]) {
        content = (NSString *)text;
    }
    // 2. 判断是否是 NSNumber 对象（调用者可能传入了 @(123) 这样的对象）
    else if ([text isKindOfClass:[NSNumber class]]) {
        content = [(NSNumber *)text stringValue];
    }
    return [NSNumber numberWithBool:[[ClipboardM clipboardM] copyToClipboard:content] ? YES : NO];
}


/// 获取剪切板内容
+ (NSString *)getClipboardText:(NSString *)value
{
    NSLog(@"value:%@", value);
    return [[ClipboardM clipboardM] getClipboardText];
}



// 支付监听
// 返回数据格式 { state, productId, transactionId, receipt }
+ (void)setIapListener:(NSString *)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"设置支付监听.");
        [[IapM iapM] initGame];
        [[IapM iapM] setTransactionListener:^(NSDictionary * dict) {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            NSLog(@"监听到支付消息：%@", jsonString);
            [[conchRuntime GetIOSConchRuntime]callbackToJSWithClass:self.class methodName:@"setIapListener:" ret:jsonString];
        }];
    });
}

/// 支付商品
/// - Parameter json: { productId: }
+ (void)iapPurchase:(NSString *)value
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // 商品id。如果为Number类型需要转换为String类型
        NSString *productId = nil;
        if([value isKindOfClass:[NSString class]]){
            productId = value;
        }else if([value isKindOfClass:[NSNumber class]]){
            productId = [(NSNumber *)value stringValue];
        }
        NSLog(@"购买商品ID：%@", productId);
        if(productId){
            NSSet * list = [NSSet setWithObject:productId];
            [[IapM iapM] requestProducts:list completion:^(SKProductsRequest * request, SKProductsResponse * response) {
                NSLog(@"请求支付");
                SKProduct *product = response.products.firstObject;
                [[IapM iapM] purchase:product];
            }];
        }
    });
}


/// 完成交易
/// - Parameter transactionId: <#transactionId description#>
+ (void)finishTransaction:(NSString *)transactionId
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        NSString *tempId = [IapM iapM].transaction.transactionIdentifier;
        [[IapM iapM] finishTransaction:tempId];
    });
}

/// 获取内购商品列表
/// - Parameter json: { products:[id,id,id] }
// 返回数据格式 { products:[ {productId, title, description, price, formattedPrice, currencySymbol} ] }
+ (void)getIapProduces:(NSString *)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
        
        if(dict[@"products"]){
            NSSet *products = [NSSet setWithArray:dict[@"products"]];
            NSLog(@"前端查询商品列表：%@", products);
            [[IapM iapM] requestProducts:products completion:^(SKProductsRequest * request, SKProductsResponse * response) {
                NSDictionary * list = [[IapM iapM] productsToDict:response];
                
                NSError *error = nil;
                NSData *jsonData = [NSJSONSerialization dataWithJSONObject:list options:NSJSONWritingPrettyPrinted error:&error];
                NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
                
                NSLog(@"商品JSON字符串：%@", jsonString);
                [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self.class methodName:@"getIapProduces:" ret:jsonString];
            }];
        }
    });
}

/// 友盟上报埋点
/// - Parameter json: { eventId, attributes:{ key:value } }
+ (void)umengEvent:(NSString *)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
        
        NSString *eventId = json[@"eventId"];
        NSDictionary *attributes = json[@"attributes"];
        if(eventId && attributes){
            [UmengM event:eventId attributes:attributes];
        }
    });
}


/// 获取上方安全区域尺寸
+ (NSNumber *)getStatusBarHeight:(NSString *)value
{
    return [NSNumber numberWithFloat:[UtilsM getStatusBarHeight]];
}


/// 获取屏幕信息
/// 返回数据格式 { width:x, height:x, statusBarHeight:x }
+ (NSString *)getScreenInfo:(NSString *)value
{
    NSDictionary *info = [UtilsM getScreenInfo];
    
    NSLog(@"屏幕信息：%@", info);
    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:info options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    return jsonStr;
}



/// 加载激励视频广告
/// - Parameter dict: { placementId }
// 返回数据格式 { status:ONADLOAD } status对应的值为常量字符串
+ (void)loadAdVideo:(NSString *)dict
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *data = [dict dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        NSString *placementId = json[@"placementId"];
        
        [[YlhAdM sharedManager] loadVideo:placementId completion:^(NSDictionary *dict) {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"loadAdVideo:" ret:jsonStr];
        }];
    });
}

/// 显示激励视频广告
+ (void)showAdVideo:(NSString *)json
{
    [[YlhAdM sharedManager]showVideo];
}


/// 加载激励视频广告
/// - Parameter dict: { placementId }
// 返回数据格式 { status:ONADLOAD } status对应的值为常量字符串
+ (void)loadALAdVideo:(NSString *)dict
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *data = [dict dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        NSString *placementId = json[@"placementId"];
        
        [[ALAdM sharedManager] loadVideo:placementId completion:^(NSDictionary *dict) {
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"loadALAdVideo:" ret:jsonStr];
        }];
    });
}

/// 显示激励视频广告
+ (void)showALAdVideo:(NSString *)json
{
    [[ALAdM sharedManager]showVideo];
}

/// 打开应用商店
/// - Parameter url: 商店地址
+ (void)openAppStore:(NSString *)url
{
    [UtilsM openAppStore:url];
}

/// 重启  当前接口负责将启动页重新显示，显示后的js 回调函数中需要html页面自己reload一下
+ (void)rebootApp:(NSString *)value
{
    dispatch_async(dispatch_get_main_queue(), ^{
        AppDelegate * appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        [appDelegate.window.rootViewController.view addSubview:appDelegate.launchView.view];
        [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"rebootApp:" ret:@""];
    });
}

/// 关闭app   模拟关闭app（直接关闭app违反ios上架规则）
+ (void)closeApp:(NSString *)value
{
    [UtilsM closeApp];
}


/// 震动  long 长震动。short 短震动
+ (void)vibrate:(NSString *)type
{
    if([type isKindOfClass:[NSString class]] && [type isEqualToString:@"long"]){
        NSLog(@"长震动");
        [UtilsM vibrateLong];
    }else{
        NSLog(@"短震动");
        [UtilsM vibrateShort];
    }
}

// 获取某项权限的状态信息
// 返回数据格式 { status:true|false, msg:"" }
+ (void)permission:(NSString *)name
{
    // 获取定位权限状态
    if([name isEqualToString:@"location"]){
        [[LocationM locationM] getAuth:^(LocationAuthorizationStatus status) {
            // 状态说明
            NSString *msg = [[LocationM locationM] getAuthDes:status];
            // 返回的数据格式
            NSDictionary *dict = @{ @"status":status == LocationAuthorizationStatusAuthorized ? @YES : @NO, @"msg":msg };
            
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            
            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"permission:" ret:jsonStr];
        }];
    }
    // 获取麦克风权限状态
    else if([name isEqualToString:@"microphone"]){
        // 状态值
        RecorderAuthStatus status = [[RecorderM recorderM] getAuth];
        // 状态说明
        NSString *msg = [[RecorderM recorderM] getAuthDes:status];
        // 返回的数据格式
        NSDictionary *dict = @{ @"status":status == RecorderAuthStatusAuthorized ? @YES : @NO, @"msg":msg };
        
        NSError *error = nil;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
        NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        
        [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"permission:" ret:jsonStr];
        
    }
}

// 请求授权
// 返回数据格式 { status:true|false, code:1001, msg:"" }
+ (void)requestAuth:(NSString *)name
{
    // 请求定位授权
    if([name isEqualToString:@"location"]){
        [LocationM locationM].completionBlock = ^(NSDictionary * dict) {
            NSLog(@"授权结果：%@", dict);
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"requestAuth:" ret:jsonStr];
        };
        [[LocationM locationM] requestAuth];
    }
    // 请求麦克风授权
    else if([name isEqualToString:@"microphone"]){
            
        [[RecorderM recorderM] requestAuth:^(NSDictionary * result) {
            NSLog(@"授权结果：%@", result);
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"requestAuth:" ret:jsonStr];
        }];
    }
    // 请求广告IDFA授权
    else if([name isEqualToString:@"ad"]){
        [[YlhAdM sharedManager] requestAuth:^(AdAuthorizationStatus status) {
            NSLog(@"授权结果：%ld", status);
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"status":@(status)} options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"requestAuth:" ret:jsonStr];
        }];
    }
}

// 获取定位信息(包含经纬度信息)
// 失败返回数据格式 { status:true|false, latitude:"", longitude:"" }
// 失败返回数据格式 { status:true|false, code:1001, msg:"" }
+ (void)getLocation:(NSString *)value
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [LocationM locationM].completionBlock = ^(NSDictionary * dict) {
            NSLog(@"定位信息：%@", dict);
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"getLocation:" ret:jsonStr];
        };
        [[LocationM locationM] getLocation];
    });
}

// 开启录音
// 成功返回数据格式 { status:true|false, msg:"", wavPath:"", saveDirectory:"" }
// 失败返回数据格式 { status:true|false, code:1001, msg:"" }
+ (void)startRecoder:(NSString *)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RecorderM recorderM] startRecording:^(NSDictionary * _Nullable result) {
            NSLog(@"开始录音：%@", result);
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"startRecoder:" ret:jsonStr];
        }];
    });
}

// 停止录音
// 成功返回数据格式 { status:true|false, amrPath:“”, wavPath:"", duration:"" }
// 失败返回数据格式 { status:true|false, code:1001, msg:"" }
+ (void)stopRecoder:(NSString *)value
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [[RecorderM recorderM] stopRecording:^(NSDictionary * _Nullable result) {
            NSLog(@"停止录音：%@", result);
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:result options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"stopRecoder:" ret:jsonStr];
        }];
    });
}

// 上传录音  json 中需要包含2个参数  { url, values:{ param1:x, param2:x } }
// 返回数据格式 { status:true|false, error:{} }
+ (void)uploadRecoder:(NSString *)json
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
        
        NSLog(@"上传数据：%@", dict);
        // 获取amr音频文件路径
        NSString *path = [[RecorderM recorderM] getCurrentAMRFilePath];
        // 附带参数
        NSDictionary *values = dict[@"values"];
        // 音频上传地址
        NSString *url = dict[@"url"];
        // 上传音频文件
        [HttpRequest uploadReq:url parameters:values filePath:path fileFieldName:@"file" completion:^(NSDictionary *response, NSError *error) {
                if(error){
                    NSLog(@"上传失败：%@", error.localizedDescription);
                    NSError *error = nil;
                    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"status":@NO, @"error":error } options:NSJSONWritingPrettyPrinted error:&error];
                    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

                    [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"uploadRecoder:" ret:jsonStr];
                }else{
                    NSLog(@"上传成功：%@", response);
                    NSError *error = nil;
                    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"status":@YES} options:NSJSONWritingPrettyPrinted error:&error];
                    NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

                    [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"uploadRecoder:" ret:jsonStr];
                }
        }];
        
    });
}


+ (void)playVoice:(NSString *)url{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"音频地址：%@", url);
        [UtilsM playVoice:url completion:^(NSDictionary * _Nonnull dict) {
            if([dict[@"status"] boolValue]){
                NSLog(@"播放完成");
            }else{
                NSLog(@"播放失败：%@", dict[@"msg"]);
            }
            
            NSError *error = nil;
            NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:&error];
            NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
            // 不论成功或者失败，都执行回调
            [[conchRuntime GetIOSConchRuntime] callbackToJSWithClass:self methodName:@"playVoice:" ret:jsonStr];
        }];
    });
}

/// 获取唯一的设备id
+ (NSString *)getDeviceUUID:(NSString *)value
{
    NSString *uuid = [UtilsM getDeviceUUID];
    NSLog(@"设备ID:%@", uuid);
    return uuid;
}


@end

