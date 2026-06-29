//
//  ClipboardM.h
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/11.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ClipboardM : NSObject

+ (instancetype)clipboardM;

- (BOOL)copyToClipboard:(NSString *)text;

- (NSString * _Nullable)getClipboardText;

@end

NS_ASSUME_NONNULL_END
