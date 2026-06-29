//
//  UmengM.m
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/26.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import "UmengM.h"
#import "UMCommon/UMCommon.h"

NS_ASSUME_NONNULL_BEGIN

@implementation UmengM

+ (void)event:(nonnull NSString *)eventId {
    [MobClick event:eventId];
}

+ (void)event:(nonnull NSString *)eventId label:(nonnull NSString *)label {
    [MobClick event:eventId label:label];
}

+ (void)event:(nonnull NSString *)eventId attributes:(nonnull NSDictionary *)attributes {
    [MobClick event:eventId attributes:attributes];
}

+ (void)event:(nonnull NSString *)eventId attributes:(nonnull NSDictionary *)attributes counter:(int)number {
    [MobClick event:eventId attributes:attributes counter:number];
}

@end

NS_ASSUME_NONNULL_END
