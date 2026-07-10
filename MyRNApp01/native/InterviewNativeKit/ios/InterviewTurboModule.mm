#import <Foundation/Foundation.h>
#import <React/RCTBridgeModule.h>
#import <ReactCommon/RCTTurboModule.h>

#if __has_include(<ReactCodegen/InterviewNativeKit/InterviewNativeKit.h>)
#import <ReactCodegen/InterviewNativeKit/InterviewNativeKit.h>
#elif __has_include(<InterviewNativeKit/InterviewNativeKit.h>)
#import <InterviewNativeKit/InterviewNativeKit.h>
#elif __has_include(<ReactCodegen/InterviewNativeKit.h>)
#import <ReactCodegen/InterviewNativeKit.h>
#elif __has_include("InterviewNativeKit.h")
#import "InterviewNativeKit.h"
#endif

@interface InterviewTurboModule : NSObject <NativeInterviewTurboModuleSpec>
@end

@implementation InterviewTurboModule

RCT_EXPORT_MODULE(InterviewTurboModule)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

- (NSDictionary *)getDeviceInfo
{
  NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
  return @{
    @"platform" : @"ios",
    @"systemVersion" : [NSProcessInfo processInfo].operatingSystemVersionString ?: @"unknown",
    @"model" : @"iPhone / iOS Simulator",
    @"appVersion" : info[@"CFBundleShortVersionString"] ?: @"1.0",
    @"isHermes" : @YES,
    @"isNewArchitecture" : @YES,
  };
}

- (NSNumber *)getTimestamp
{
  return @([[NSDate date] timeIntervalSince1970] * 1000.0);
}

- (void)getTimestampAsync:(RCTPromiseResolveBlock)resolve reject:(RCTPromiseRejectBlock)reject
{
  resolve(@([[NSDate date] timeIntervalSince1970] * 1000.0));
}

- (void)logNativeMessage:(NSString *)message
{
  NSLog(@"[InterviewTurboModule] %@", message);
}

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
  return std::make_shared<facebook::react::NativeInterviewTurboModuleSpecJSI>(params);
}

@end
