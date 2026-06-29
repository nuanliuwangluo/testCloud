//
//  IapM.h
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/15.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface IapM : NSObject <SKPaymentTransactionObserver, SKProductsRequestDelegate>

@property (nonatomic, copy, nullable) void (^requestBlock)(SKProductsRequest * request, SKProductsResponse * response);

@property (nonatomic, copy, nullable) void (^listenerBlock)(NSDictionary * dict);

@property (nonatomic, strong, nullable) SKPaymentTransaction *transaction;

+ (instancetype)iapM;

- (void)initGame;

- (void)requestProducts:(NSSet *)products completion:(void(^)(SKProductsRequest * request, SKProductsResponse * response))completion;

- (void)setTransactionListener:(void(^)(NSDictionary * dict))completion;

- (void)purchase:(SKProduct *)product;

- (void)finishTransaction:(NSString *)transactionId;

- (NSDictionary *)productsToDict:(SKProductsResponse *)response;
@end

NS_ASSUME_NONNULL_END
