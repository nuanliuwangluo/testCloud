//
//  HttpRequest.m
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/9.
//  Copyright © 2025 mjxxl. All rights reserved.
//


#import "HttpRequest.h"

@implementation HttpRequest

// GET请求实现
+ (void)getReq:(NSString *)url
        parameters:(NSDictionary *)parameters
        completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion {
    
    // 处理URL参数
    NSString *fullURL = url;
    if (parameters && parameters.count > 0) {
        NSString *queryString = [self queryStringFromParameters:parameters];
        fullURL = [NSString stringWithFormat:@"%@?%@", url, queryString];
    }
    
    NSURL *requestURL = [NSURL URLWithString:fullURL];
    if (!requestURL) {
        if (completion) {
            completion(nil, nil, [NSError errorWithDomain:@"Invalid URL" code:-1 userInfo:nil]);
        }
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 30.0;
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *taskError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(data, response, taskError);
            }
        });
    }];
    
    [task resume];
}

// POST请求实现
+ (void)postReq:(NSString *)url
         parameters:(NSDictionary *)parameters
         completion:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completion {
    
    NSURL *requestURL = [NSURL URLWithString:url];
    if (!requestURL) {
        if (completion) {
            completion(nil, nil, [NSError errorWithDomain:@"Invalid URL" code:-1 userInfo:nil]);
        }
        return;
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:requestURL];
    request.HTTPMethod = @"POST";
    request.timeoutInterval = 30.0;
    
    // 设置请求头
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    
    // 处理请求体
    if (parameters && parameters.count > 0) {
        NSError *jsonError;
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:&jsonError];
        if (jsonError) {
            if (completion) {
                completion(nil, nil, jsonError);
            }
            return;
        }
        request.HTTPBody = jsonData;
    }
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *taskError) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(data, response, taskError);
            }
        });
    }];
    
    [task resume];
}

// 辅助方法：将参数字典转换为查询字符串
+ (NSString *)queryStringFromParameters:(NSDictionary *)parameters {
    NSMutableArray *components = [NSMutableArray array];
    for (NSString *key in parameters) {
        NSString *value = [NSString stringWithFormat:@"%@", parameters[key]];
        NSString *encodedKey = [key stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *encodedValue = [value stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        [components addObject:[NSString stringWithFormat:@"%@=%@", encodedKey, encodedValue]];
    }
    return [components componentsJoinedByString:@"&"];
}

// 根据文件名获取 MIME TYPE
+ (NSString *)mimeTypeForFileExtension:(NSString *)extension
{
    if([extension isEqualToString:@"amr"]){
        return @"audio/amr";
    }else if([extension isEqualToString:@"m4a"]){
        return @"audio/m4a";
    }else if([extension isEqualToString:@"mp3"]){
        return @"audio/mpeg";
    }else if([extension isEqualToString:@"wav"]){
        return @"audio/wav";
    }else if([extension isEqualToString:@"aac"]){
        return @"audio/aac";
    }
    return @"application/octet-stream";
}


+ (void)uploadReq:(NSString *)url
            parameters:(NSDictionary *)parameters
                filePath:(NSString *)filePath
                    fileFieldName:(NSString *)fileFieldName
                        completion:(void (^)(NSDictionary *, NSError *))completion {
    // 检查文件是否存在
    NSFileManager *fileManager = [NSFileManager defaultManager];
    // 音频文件不存在
    if(![fileManager fileExistsAtPath:filePath]){
        NSError *error = [NSError errorWithDomain:@"uploadError" code:1001 userInfo:@{NSLocalizedDescriptionKey:@"音频文件不存在"}];
        if(completion){ completion(nil, error); }
        return;
    }
    // 获取文件数据
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    // 读取音频文件失败
    if(!fileData){
        NSError *error = [NSError errorWithDomain:@"uploadError" code:1002 userInfo:@{NSLocalizedDescriptionKey:@"读取音频文件失败"}];
        if(completion){ completion(nil, error); }
        return;
    }
    // 获取文件名
    NSString *fileName = [filePath lastPathComponent];
    // 构建multipart/form-data 请求
    NSURL *reqUrl = [NSURL URLWithString:url];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:reqUrl];
    [request setHTTPMethod:@"POST"];
    // 生成边界字符
    NSString *boundary = [NSString stringWithFormat:@"Boundary-%@", [[NSUUID UUID] UUIDString]];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", boundary];
    [request setValue:contentType forHTTPHeaderField:@"Content-Type"];
    // 构建请求体
    NSMutableData *body = [NSMutableData data];
    
    // 添加表单参数 -- 对应apicloud 的 values
    for (NSString *key in parameters) {
        id value = parameters[key];
        // 添加参数边界
        [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
        // 添加头部参数
        [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
        // 添加参数值
        [body appendData:[[NSString stringWithFormat:@"%@\r\n", value] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    
    // 添加文件 -- 对应apicloud 的 files
    [body appendData:[[NSString stringWithFormat:@"--%@\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [body appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", fileFieldName, fileName] dataUsingEncoding:NSUTF8StringEncoding]];
    // 根据文件扩展名设置content-type
    NSString *fileExtension = [fileName pathExtension];
    NSString *mimeType = [self mimeTypeForFileExtension:fileExtension];
    [body appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", mimeType] dataUsingEncoding:NSUTF8StringEncoding]];
    
    // 添加文件数据
    [body appendData:fileData];
    [body appendData:[@"\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
    
    // 添加结束边界
    [body appendData:[[NSString stringWithFormat:@"--%@--\r\n", boundary] dataUsingEncoding:NSUTF8StringEncoding]];
    // 设置请求体
    [request setHTTPBody:body];
    
    // 创建上传任务
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    
    NSURLSessionUploadTask *uploadTask = [session uploadTaskWithRequest:request fromData:body completionHandler:^(NSData * data, NSURLResponse * response, NSError * error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            //上传失败
            if(error){
                if(completion){
                    completion(nil, error);
                }
                return;
            }
            // 解析响应数据
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if(httpResponse.statusCode >= 200 && httpResponse.statusCode < 300){
                // 成功
                if(data && data.length > 0){
                    NSError *jsonError = nil;
                    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
                    if(jsonError){
                        //返回的不是json，可能是纯文本
                        NSString *responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                        if(completion){
                            completion(@{@"response":responseString}, nil);
                        }
                    }else{
                        if(completion){
                            completion(responseDict, nil);
                        }
                    }
                }else{
                    //失败
                    if(completion){
                        completion(@{}, nil);
                    }
                }
            }else{
                //http 错误
                NSError *httpError = [NSError errorWithDomain:@"uploadError" code:httpResponse.statusCode userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"HTTP错误：%ld", (long)httpResponse.statusCode]}];
                if(completion){
                    completion(nil, httpError);
                }
            }
        });
    }];
    
    // 启动上传任务
    [uploadTask resume];
}

@end

