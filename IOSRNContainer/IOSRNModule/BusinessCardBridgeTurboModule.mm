#import "BusinessCardBridgeTurboModule.h"
#import <React/RCTBridgeModule.h>
#import <ReactCommon/RCTTurboModule.h>

using namespace facebook::react;

typedef void (^CardPressHandler)(NSString *cardId);
typedef void (^ActionPressHandler)(NSString *cardId, NSString *actionId, int actionType);
typedef void (^ExposureHandler)(NSString *cardId, double timestamp);

@implementation BusinessCardBridgeTurboModule {
}

static CardPressHandler _onCardPress = nil;
static ActionPressHandler _onActionPress = nil;
static ExposureHandler _onExposure = nil;
static NSString *_initialCardsPayload = nil;

RCT_EXPORT_MODULE(BusinessCardBridge)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

+ (void)setOnCardPress:(CardPressHandler)handler {
  _onCardPress = [handler copy];
}

+ (void)setOnActionPress:(ActionPressHandler)handler {
  _onActionPress = [handler copy];
}

+ (void)setOnExposure:(ExposureHandler)handler {
  _onExposure = [handler copy];
}

+ (void)setInitialCardsPayload:(NSString *)payload {
  if (_initialCardsPayload != payload) {
    _initialCardsPayload = [payload copy];
  }
}

+ (void)clearCallbacks {
  _onCardPress = nil;
  _onActionPress = nil;
  _onExposure = nil;
}

- (void)onCardPress:(NSString *)cardId {
  NSLog(@"[BusinessCardBridge] 卡片点击: %@", cardId);
  if (_onCardPress) {
    _onCardPress(cardId);
  }
}

- (void)onActionPress:(NSString *)cardId
              actionId:(NSString *)actionId
            actionType:(double)actionType {
  NSLog(@"[BusinessCardBridge] 操作点击: card=%@, action=%@, type=%f",
        cardId, actionId, actionType);
  if (_onActionPress) {
    _onActionPress(cardId, actionId, (int)actionType);
  }
}

- (void)onExposure:(NSString *)cardId
         timestamp:(double)timestamp {
  if (_onExposure) {
    _onExposure(cardId, timestamp);
  }
}

- (void)getInitialCards:(RCTPromiseResolveBlock)resolve
               rejecter:(RCTPromiseRejectBlock)reject {
  resolve(_initialCardsPayload ?: @"[]");
}

#if __has_include(<MyRNAppSpecs/MyRNAppSpecs.h>)
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
  return std::make_shared<BusinessCardBridgeSpecJSI>(params);
}
#endif

@end
