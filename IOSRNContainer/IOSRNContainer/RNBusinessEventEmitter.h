#import <React/RCTBridgeModule.h>
#import <React/RCTEventEmitter.h>

NS_ASSUME_NONNULL_BEGIN

@interface RNBusinessEventEmitter : RCTEventEmitter <RCTBridgeModule>

/// 单例：RN 初始化模块时自动赋值，Swift 侧无需通过 bridge 获取
+ (nullable instancetype)sharedInstance;

- (void)sendBusinessData:(NSString *)callbackId payload:(NSDictionary *)payload;

@end

NS_ASSUME_NONNULL_END
