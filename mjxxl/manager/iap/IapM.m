//
//  IapM.m
//  mjxxl
//
//  Created by 王兴伟 on 2025/12/15.
//  Copyright © 2025 mjxxl. All rights reserved.
//

#import "IapM.h"

NS_ASSUME_NONNULL_BEGIN

@implementation IapM

+ (instancetype)iapM {
    static IapM *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[IapM alloc] init];
    });
    return instance;
}


- (void)initGame
{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}


/// 设置监听函数
/// - Parameter completion: <#completion description#>
- (void)setTransactionListener:(void (^)(NSDictionary *))completion
{
    self.listenerBlock = completion;
}


/// 支付
/// - Parameter product: 商品
- (void)purchase:(SKProduct *)product
{
    // 还有没有核销的商品
    if(self.transaction){
        NSLog(@"支付留存。");
        [self transactionHandle:self.transaction];
    }
    // 没有要核销的交易了， 发起支付
    else{
        SKPayment *payment = [SKPayment paymentWithProduct:product];
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}


/// 发起商品信息查询
/// - Parameters:
///   - products: 商品id集合
///   - completion: 回调
- (void)requestProducts:(NSSet *)products completion:(void(^)(SKProductsRequest * request, SKProductsResponse * response))completion
{
    self.requestBlock = completion;
    SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:products];
    request.delegate = self;
    [request start];
}


/// 完成交易
/// - Parameter transactionId: 交易id
- (void)finishTransaction:(NSString *)transactionId
{
    if(self.transaction && transactionId){
        // 完成的交易为当前记录的
        if([self.transaction.transactionIdentifier isEqual:transactionId]){
            NSLog(@"完成交易：%@", transactionId);
            [[SKPaymentQueue defaultQueue] finishTransaction:self.transaction];
            self.transaction = nil;
        }
    }
}












/// 支付监听
/// - Parameters:
///   - queue: <#queue description#>
///   - transactions: <#transactions description#>
- (void)paymentQueue:(nonnull SKPaymentQueue *)queue updatedTransactions:(nonnull NSArray<SKPaymentTransaction *> *)transactions {
    
    for (SKPaymentTransaction *transaction in transactions)
    {
        self.transaction = transaction;
        [self transactionHandle:transaction];
    }
}



/// 商品查询结果
/// - Parameters:
///   - request: <#request description#>
///   - response: <#response description#>
- (void)productsRequest:(nonnull SKProductsRequest *)request didReceiveResponse:(nonnull SKProductsResponse *)response {
    if(self.requestBlock){
        self.requestBlock(request, response);
    }
}




/// 交易处理
/// - Parameter transaction: <#transaction description#>
- (void)transactionHandle:(SKPaymentTransaction *)transaction
{
    NSString *productId = transaction.payment.productIdentifier; // 商品id
    NSString *transactionReceipt = [self receiptToBase64:transaction];// 商品交易凭证
    NSString *transactionId = transaction.transactionIdentifier;// 交易id
    
    NSString *msg = nil;
    if (transaction.transactionState == SKPaymentTransactionStatePurchased){
        NSLog(@"交易成功.");
        msg = @"交易成功";
    }else if (transaction.transactionState == SKPaymentTransactionStateFailed){
        if (transaction.error.code != SKErrorPaymentCancelled) {
            // 非用户取消的失败（如网络问题、购买不允许等）
            // 在这里展示错误提示
            msg = @"交易失败";
        } else {
            // 用户主动取消
            // 在这里进行取消后的处理，例如更新UI、关闭等待框等
            msg = @"用户取消交易";
        }
        [[SKPaymentQueue defaultQueue] finishTransaction:self.transaction];
        self.transaction = nil;
    }else if (transaction.transactionState == SKPaymentTransactionStatePurchasing){
        NSLog(@"交易中.");
        msg = @"交易中";
        return;
    }else if (transaction.transactionState == SKPaymentTransactionStateRestored){
        
    }
    
    
    NSLog(@"商品id：%@", productId);
    NSLog(@"交易id：%@", transactionId);
    NSLog(@"交易凭证：%@", transactionReceipt);
    NSLog(@"交易状态：%ld", (long)transaction.transactionState);
    
    NSDictionary *responseDict = [NSDictionary dictionaryWithObjectsAndKeys:@((long)transaction.transactionState), @"state",
                                  productId, @"productId",
                                  msg, @"msg",
                                  transactionId, @"transactionId",
                                  transactionReceipt, @"receipt",
                                  nil];
    [self iapResponseClient:responseDict];
}




/// 商品信息整理到 Object 的 products属性中
/// - Parameter response: <#response description#>
- (NSDictionary *)productsToDict:(SKProductsResponse *)response
{
    NSMutableArray *list = [NSMutableArray array];
    for (SKProduct *product in response.products) {
        NSDictionary *info = [self analysisProduct:product];
        [list addObject:info];
    }
//    NSLog(@"数组内容：%@", list);
    NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:list, @"products", nil];
    return dict;
}

/// 解析商品信息
/// - Parameter product: <#product description#>
- (NSDictionary *)analysisProduct:(SKProduct *)product
{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];

    // 获取货币代码（如 "CNY", "USD"）
    NSString *currencyCode = [product.priceLocale objectForKey:NSLocaleCurrencyCode];
    NSString *formattedPrice;

    if ([currencyCode isEqualToString:@"CNY"]) {
        // 人民币特殊处理：去掉符号，后面加"元"
        [numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
        [numberFormatter setMinimumFractionDigits:2];
        [numberFormatter setMaximumFractionDigits:2];
        NSString *priceValue = [numberFormatter stringFromNumber:product.price];
        formattedPrice = [NSString stringWithFormat:@"%@元", priceValue];
    } else {
        // 其他货币保持默认格式
        formattedPrice = [numberFormatter stringFromNumber:product.price];
    }

    // 如果需要单独获取货币符号（人民币时返回 @"¥"）
    NSString *currencySymbol = [product.priceLocale objectForKey:NSLocaleCurrencySymbol];
    
//    NSLog(@"商品id：%@", product.productIdentifier);
//    NSLog(@"商品标题：%@", product.localizedTitle);
//    NSLog(@"商品描述：%@", product.localizedDescription);
//    NSLog(@"商品价格：%@", product.price);
//    NSLog(@"商品格式化价格：%@", formattedPrice);
//    NSLog(@"价格区域：%@", product.priceLocale.localeIdentifier);
//    NSLog(@"是否可以购买：%d", product.isDownloadable);
    
    
    NSDictionary *productInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                          product.productIdentifier, @"productId",
                          product.localizedTitle, @"title",
                          product.localizedDescription, @"description",
                          product.price, @"price",
                          formattedPrice, @"formattedPrice",
                          currencySymbol, @"currencySymbol",
                          nil];
    return productInfo;
}


/// 交易凭证转换为mjxxl64
/// - Parameter transaction: <#transaction description#>
- (NSString *)receiptToBase64:(SKPaymentTransaction *)transaction
{
    NSData *receiptData = nil;
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:receiptURL.path]){
        receiptData = [NSData dataWithContentsOfURL:receiptURL];
    }else{
        receiptData = transaction.transactionReceipt;
    }
    
    if(!receiptData){
        NSLog(@"无法获取收据数据.");
        [self finishTransaction:transaction.transactionIdentifier];
    }
    
    NSString *receiptBase64 = [receiptData base64EncodedStringWithOptions:0];
    return receiptBase64;
    
}


/// 支付结果反馈给前端
/// - Parameter dict: <#dict description#>
- (void)iapResponseClient:(NSDictionary *)dict
{
    if(self.listenerBlock){
        self.listenerBlock(dict);
    }
}

@end

NS_ASSUME_NONNULL_END
