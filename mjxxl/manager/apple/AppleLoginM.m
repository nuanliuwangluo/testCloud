//
//  AppleLogin.m
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/12.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import "AppleLoginM.h"

NS_ASSUME_NONNULL_BEGIN

@implementation AppleLoginM

+ (instancetype)appleLoginM {
    static AppleLoginM *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AppleLoginM alloc] init];
    });
    return instance;
}

- (BOOL)isAppleLoginAuthorized {
    if(@available(iOS 13.0, *)){
        NSString *savedUserId = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleLoginUserId"];
        return savedUserId != nil;
    }
    return NO;
}


- (void)login {
    if(@available(iOS 13.0, *)){
        ASAuthorizationAppleIDProvider *provider = [[ASAuthorizationAppleIDProvider alloc] init];
        ASAuthorizationAppleIDRequest *request = [provider createRequest];
        request.requestedScopes = @[ASAuthorizationScopeFullName, ASAuthorizationScopeEmail];
        
        ASAuthorizationController *controller = [[ASAuthorizationController alloc] initWithAuthorizationRequests:@[request]];
        controller.delegate = self;
        controller.presentationContextProvider = self;
        
        [controller performRequests];
    }else{
        NSDictionary *dict = @{ @"code" : @(AppleLoginOld) };
        self.loginHandler(dict);
    }
}


- (void)clearAppleLoginState {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AppleLoginUserId"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AppleLoginEmail"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"AppleLoginFullName"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


#pragma mark - ASAuthorizationControllerDelegate
- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithAuthorization:(ASAuthorization *)authorization
API_AVAILABLE(ios(13.0)){
    if([authorization.credential isKindOfClass:[ASAuthorizationAppleIDCredential class]]){
        ASAuthorizationAppleIDCredential *appleIDCredential = (ASAuthorizationAppleIDCredential *)authorization.credential;
        
        NSString *userId = appleIDCredential.user;
        NSString *email = appleIDCredential.email;
        NSPersonNameComponents *nameComponents = appleIDCredential.fullName;
        NSString *fullName = @"";
        
        if(nameComponents){
            NSMutableString *nameString = [NSMutableString string];
            if(nameComponents.givenName){
                [nameString appendString:nameComponents.givenName];
            }
            if(nameComponents.familyName){
                if(nameString.length > 0){
                    [nameString appendString:@" "];
                }
                [nameString appendString:nameComponents.familyName];
            }
            fullName = [nameString copy];
            
            if(fullName.length > 0){
                [[NSUserDefaults standardUserDefaults] setObject:fullName forKey:@"AppleLoginFullName"];
            }
        }else{
            fullName = [[NSUserDefaults standardUserDefaults] stringForKey:@"AppleLoginFullName"] ?: @"";
        }
        
        NSData *identityToken = appleIDCredential.identityToken;
        NSString *identityTokenString = nil;
        
        if(identityToken){
            identityTokenString = [[NSString alloc] initWithData:identityToken encoding:NSUTF8StringEncoding];
            NSLog(@"授权token：%@, tokenToString:%@", identityToken, identityTokenString);
        }
        
        NSData *authorizationCode = appleIDCredential.authorizationCode;
        if(authorizationCode){
//            NSString *authCodeString = [[NSString alloc] initWithData:authorizationCode encoding:NSUTF8StringEncoding];
        }
        
        NSDictionary *dict = @{ @"code":@(AppleLoginSuccess), @"msg":@"授权成功", @"fullName":fullName, @"userId":userId, @"email":email ?: @"", @"identityToken":identityTokenString ?: @"" };
        self.loginHandler(dict);
    }
}

- (void)authorizationController:(ASAuthorizationController *)controller didCompleteWithError:(NSError *)error
API_AVAILABLE(ios(13.0)){
    NSDictionary *dict;
    switch (error.code) {
        case ASAuthorizationErrorCanceled:
            dict = @{ @"code":@(AppleLoginCanceled), @"msg":@"用户取消授权" };
            self.loginHandler(dict);
            break;
            
        case ASAuthorizationErrorFailed:
            dict = @{ @"code":@(AppleLoginFailed), @"msg":@"授权请求失败" };
            self.loginHandler(dict);
            break;
            
        case ASAuthorizationErrorInvalidResponse:
            dict = @{ @"code":@(AppleLoginInvalidResponse), @"msg":@"授权响应无效" };
            self.loginHandler(dict);
            break;
            
        case ASAuthorizationErrorNotHandled:
            dict = @{ @"code":@(AppleLoginNotHandled), @"msg":@"授权请求未处理" };
            self.loginHandler(dict);
            break;
            
        case ASAuthorizationErrorUnknown:
            dict = @{ @"code":@(AppleLoginUnknown), @"msg":@"未知错误" };
            self.loginHandler(dict);
            break;
            
        default:
            break;
    }
}


#pragma mark - ASAuthorizationControllerPresentationContextProviding
- (ASPresentationAnchor)presentationAnchorForAuthorizationController:(ASAuthorizationController *)controller  API_AVAILABLE(ios(13.0)){
    return nil;
}

@end

NS_ASSUME_NONNULL_END
