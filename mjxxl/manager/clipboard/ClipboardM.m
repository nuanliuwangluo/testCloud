//
//  ClipboardM.m
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/11.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import "UIKit/UIKit.h"
#import "ClipboardM.h"

@implementation ClipboardM

+ (instancetype)clipboardM {
    static ClipboardM *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ClipboardM alloc] init];
    });
    return instance;
}

- (BOOL)copyToClipboard:(NSString *)text {
    if(!text || text.length == 0){
        return false;
    }
    @try {
        [UIPasteboard generalPasteboard].string = text;
        return true;
    } @catch (NSException *exception) {
        return false;
    }
}


- (NSString * _Nullable)getClipboardText {
    NSString *text = [UIPasteboard generalPasteboard].string;
    if(text){
        return text;
    }else{
        return @"";
    }
}



@end
