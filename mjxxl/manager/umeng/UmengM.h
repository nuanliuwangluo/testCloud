//
//  UmengM.h
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/26.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface UmengM : NSObject

+ (void)event:(NSString *)eventId;
+ (void)event:(NSString *)eventId label:(NSString *)label;
+ (void)event:(NSString *)eventId attributes:(NSDictionary *)attributes;
+ (void)event:(NSString *)eventId attributes:(NSDictionary *)attributes counter:(int)number;

@end

NS_ASSUME_NONNULL_END
