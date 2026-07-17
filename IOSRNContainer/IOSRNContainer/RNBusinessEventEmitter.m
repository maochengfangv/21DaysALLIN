#import "RNBusinessEventEmitter.h"
#import "RNBusinessConstants.h"

static RNBusinessEventEmitter *_sharedInstance = nil;

@implementation RNBusinessEventEmitter

RCT_EXPORT_MODULE(RNBusinessEventEmitter)

+ (nullable instancetype)sharedInstance {
  return _sharedInstance;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _sharedInstance = self;
  }
  return self;
}

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (NSArray<NSString *> *)supportedEvents
{
  return @[ RNBusinessEventName ];
}

- (void)sendBusinessData:(NSString *)callbackId payload:(NSDictionary *)payload
{
  if (!self.bridge) {
    return;
  }

  [self sendEventWithName:RNBusinessEventName
                     body:@{
                       @"callbackId" : callbackId ?: @"",
                       @"payload" : payload ?: @{},
                     }];
}

@end
