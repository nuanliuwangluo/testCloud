//
//  HttpRequest.h
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/9.
//  Copyright © 2025 mjxxl. All rights reserved.
//


#import <Foundation/Foundation.h>

@interface HttpRequest: NSObject

// GET请求方法
+ (void)getReq:(NSString *)url
        parameters:(NSDictionary *)parameters
        completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion;

// POST请求方法
+ (void)postReq:(NSString *)url
         parameters:(NSDictionary *)parameters
         completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion;


+ (void)uploadReq:(NSString *)url
        parameters:(NSDictionary *)parameters
        filePath:(NSString *)filePath
        fileFieldName:(NSString *)fileFieldName
       completion:(void (^)(NSDictionary * response, NSError * error))completion;
@end

