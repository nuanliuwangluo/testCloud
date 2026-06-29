//
//  AppleLogin.h
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/12.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AuthenticationServices/AuthenticationServices.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppleLoginM : NSObject <ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding>

typedef NS_ENUM(NSInteger, AppleLoginError){
    AppleLoginSuccess = 0,
    AppleLoginOld = -1,
    AppleLoginCanceled = -2,
    AppleLoginFailed = -3,
    AppleLoginInvalidResponse = -4,
    AppleLoginNotHandled = -5,
    AppleLoginUnknown = -6
};

@property (nonatomic, copy, nullable) void (^loginHandler)(NSDictionary *dict);

+ (instancetype) appleLoginM;

- (void)login;

- (BOOL)isAppleLoginAuthorized;

- (void)clearAppleLoginState;

@end

NS_ASSUME_NONNULL_END
