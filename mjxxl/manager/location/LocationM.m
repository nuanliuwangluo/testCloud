//
//  LocationM.m
//  mjxxl
//
//  Created by 王兴伟 on 2026/3/24.
//  Copyright © 2026 mjxxl. All rights reserved.
//

#import "LocationM.h"

NS_ASSUME_NONNULL_BEGIN

@interface LocationM()

@property (nonatomic, strong) CLLocationManager * locationManager;

@end

@implementation LocationM

+ (instancetype)locationM {
    static LocationM *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype) init{
    self = [super init];
    if(self){
        [self setupLocationManager];
    }
    return self;
}

- (void)setupLocationManager{
    _locationManager = [[CLLocationManager alloc] init];
    _locationManager.delegate = self;
    _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    _locationManager.distanceFilter = kCLDistanceFilterNone;
}

- (void)getAuth:(void (^)(LocationAuthorizationStatus status))completion {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        LocationAuthorizationStatus status;
        if(![CLLocationManager locationServicesEnabled]){
            status = LocationAuthorizationStatusDisabled;
        } else{
            CLAuthorizationStatus clStatus = [CLLocationManager authorizationStatus];
            switch (clStatus) {
                case kCLAuthorizationStatusNotDetermined:
                    status = LocationAuthorizationStatusNotDetermined;
                    break;
                case kCLAuthorizationStatusAuthorizedWhenInUse:
                case kCLAuthorizationStatusAuthorizedAlways:
                    status =  LocationAuthorizationStatusAuthorized;
                    break;
                case kCLAuthorizationStatusDenied:
                    status =  LocationAuthorizationStatusDenied;
                    break;
                case kCLAuthorizationStatusRestricted:
                    status =  LocationAuthorizationStatusRestricted;
                    break;
                default:
                    status =  LocationAuthorizationStatusDenied;
                    break;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            if(completion){
                completion(status);
            }
        });
    });
}

- (NSString *)getAuthDes:(LocationAuthorizationStatus)status {
    switch (status) {
        case LocationAuthorizationStatusNotDetermined:
            return @"未决定(尚未请求授权)";
        case LocationAuthorizationStatusAuthorized:
            return @"已授权(可以使用定位)";
        case LocationAuthorizationStatusDenied:
            return @"已拒绝(请在设置中开启定位权限)";
        case LocationAuthorizationStatusRestricted:
            return @"受限制(可能是家长控制限制)";
        case LocationAuthorizationStatusDisabled:
            return @"定位服务未开启(请在系统中开启定位服务)";
        default:
            return @"未知";
    }
}

- (void)requestAuth {
    [self getAuth:^(LocationAuthorizationStatus status) {
            if(status == LocationAuthorizationStatusNotDetermined){
                // 使用期间授权
                [self.locationManager requestWhenInUseAuthorization];
                // 始终授权
                // [self.locationManager requestAlwaysAuthorization];
            }
    }];
}

- (void)getLocation {
    // 获取授权状态
    [self getAuth:^(LocationAuthorizationStatus status) {
        switch (status) {
            // 如果没有授权，先请求授权，授权结果在delegate 回调中处理
            case LocationAuthorizationStatusNotDetermined: {
                [self requestAuth];
                break;
            }
            // 如果已授权，开始定位
            case LocationAuthorizationStatusAuthorized: {
                [self startUpdatingLocation];
                break;
            }
            // 定位已被拒绝 返回错误信息
            case LocationAuthorizationStatusDenied:{
                NSDictionary *dict = @{
                    @"status":@NO,
                    @"code":@(1001),
                    @"msg":@"定位权限已被拒绝，请在设置中开启"
                };
                if(self.completionBlock){
                    self.completionBlock(dict);
                    self.completionBlock = nil;
                }
                break;
            }
            // 定位受限 返回错误信息
            case LocationAuthorizationStatusRestricted:{
                NSDictionary *dict = @{
                    @"code":@(1002),
                    @"status":@NO,
                    @"msg":@"定位服务受限制，无法获取位置"
                };
                if(self.completionBlock){
                    self.completionBlock(dict);
                    self.completionBlock = nil;
                }
                break;
            }
            // 定位为开启 返回错误信息
            case LocationAuthorizationStatusDisabled:{
                NSDictionary *dict = @{
                    @"code":@(1003),
                    @"status":@NO,
                    @"msg":@"系统定位服务未开启，请在设置中打开"
                };
                if(self.completionBlock){
                    self.completionBlock(dict);
                    self.completionBlock = nil;
                }
                break;
            }
        }
    }];
}

-(void)startUpdatingLocation{
    // 开始定位
    [self.locationManager startUpdatingLocation];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if(self.completionBlock){
            // 超时未获取到定位
            [self.locationManager stopUpdatingLocation];
            
            NSDictionary *dict = @{
                @"status":@NO,
                @"code":@(1004),
                @"msg":@"获取位置信息超时"
            };
            self.completionBlock(dict);
            self.completionBlock = nil;
        }
    });
}


#pragma mark - CLLocationManagerDelegate
// 授权状态改变回调
- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager{
    if (@available(iOS 14.0, *)) {
        CLAuthorizationStatus status = manager.authorizationStatus;
        if(status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways){
            [self startUpdatingLocation];
        }else if(status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted){
            if(self.completionBlock){
                NSDictionary *dict = @{
                    @"status":@NO,
                    @"code":@(1005),
                    @"msg":@"用户拒绝了定位权限"
                };
                self.completionBlock(dict);
                self.completionBlock = nil;
            }
        }
    } else {
        // Fallback on earlier versions
    }
}

/// 获取定位信息位置的回调(包含经纬度信息)
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations{
    // 最新的位置信息
    CLLocation *location = [locations lastObject];
    // 获取一次后停止定位，省电
    [manager stopUpdatingLocation];
    // 返回结果
    if(self.completionBlock){
        NSDictionary *dict = @{
            @"status":@YES,
            @"latitude":@(location.coordinate.latitude),
            @"longitude":@(location.coordinate.longitude)
        };
        self.completionBlock(dict);
        self.completionBlock = nil;
    }
}

-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error{
    // 停止定位
    [manager stopUpdatingLocation];
    // 返回错误结果
    if(self.completionBlock){
        NSLog(@"定位失败：%@", error);
        NSDictionary *dict = @{
            @"code":@(-1),
            @"status":@NO,
            @"msg":@"未知错误"
        };
        self.completionBlock(dict);
        self.completionBlock = nil;
    }
}


@end

NS_ASSUME_NONNULL_END
