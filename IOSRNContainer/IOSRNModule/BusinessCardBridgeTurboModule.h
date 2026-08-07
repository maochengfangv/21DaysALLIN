#import <Foundation/Foundation.h>
#if __has_include(<MyRNAppSpecs/MyRNAppSpecs.h>)
#import <MyRNAppSpecs/MyRNAppSpecs.h>
#endif

NS_ASSUME_NONNULL_BEGIN

#if __has_include(<MyRNAppSpecs/MyRNAppSpecs.h>)
@interface BusinessCardBridgeTurboModule : NSObject <BusinessCardBridgeSpec>
#else
@interface BusinessCardBridgeTurboModule : NSObject <RCTBridgeModule, RCTTurboModule>
#endif

+ (void)setOnCardPress:(void (^_Nullable)(NSString *cardId))handler;
+ (void)setOnActionPress:(void (^_Nullable)(NSString *cardId, NSString *actionId, int actionType))handler;
+ (void)setOnExposure:(void (^_Nullable)(NSString *cardId, double timestamp))handler;
+ (void)setInitialCardsPayload:(NSString * _Nullable)payload;
+ (void)clearCallbacks;

@end

NS_ASSUME_NONNULL_END
