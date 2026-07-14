#import "CounterTurboModule.h"

using namespace facebook::react;

@implementation CounterTurboModule {
  double _count;
}

RCT_EXPORT_MODULE(NativeCounter)

- (instancetype)init {
  if (self = [super init]) {
    _count = 0;
  }
  return self;
}

- (void)getValue:(RCTPromiseResolveBlock)resolve
          reject:(RCTPromiseRejectBlock)reject {
  resolve(@(_count));
}

- (void)increment:(double)step
          resolve:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject {
  _count += step;
  resolve(@(_count));
}

- (void)decrement:(double)step
          resolve:(RCTPromiseResolveBlock)resolve
           reject:(RCTPromiseRejectBlock)reject {
  _count -= step;
  resolve(@(_count));
}

- (void)reset:(RCTPromiseResolveBlock)resolve
       reject:(RCTPromiseRejectBlock)reject {
  _count = 0;
  resolve(nil);
}

- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
  return std::make_shared<NativeCounterSpecJSI>(params);
}

@end
