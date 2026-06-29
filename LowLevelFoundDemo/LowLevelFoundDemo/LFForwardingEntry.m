#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

static NSMutableArray<NSString *> *LFRuntimeLogs;

static void LFResetLogs(void) {
    LFRuntimeLogs = [NSMutableArray array];
}

static void LFLog(NSString *message) {
    if (LFRuntimeLogs == nil) {
        LFResetLogs();
    }
    [LFRuntimeLogs addObject:message];
}

static id LFDynamicGreeting(id self, SEL _cmd) {
    LFLog(@"resolveInstanceMethod: dynamically added implementation for dynamicGreeting");
    return @"dynamicGreeting -> method body injected at runtime";
}

@interface LFFastForwardTarget : NSObject
- (NSString *)fastGreeting;
@end

@implementation LFFastForwardTarget
- (NSString *)fastGreeting {
    return @"fastGreeting -> forwarded to backup target";
}
@end

@interface LFFullForwardProxy : NSObject
- (NSString *)fullGreeting;
@end

@implementation LFFullForwardProxy
- (NSString *)fullGreeting {
    return @"fullGreeting -> handled by NSInvocation forwarding";
}
@end

@interface LFMessageReceiver : NSObject
@end

@implementation LFMessageReceiver

+ (BOOL)resolveInstanceMethod:(SEL)sel {
    // 第一阶段：动态方法解析。
    // 当对象第一次接收到无法识别的 selector 时，runtime 会先给类一次“临时补方法”的机会。
    if (sel == NSSelectorFromString(@"dynamicGreeting")) {
        return class_addMethod(self, sel, (IMP)LFDynamicGreeting, "@@:");
    }
    return [super resolveInstanceMethod:sel];
}

- (id)forwardingTargetForSelector:(SEL)sel {
    // 第二阶段：快速转发。
    // 不自己处理消息，直接把接收者替换成另一个对象，成本比 NSInvocation 更低。
    if (sel == NSSelectorFromString(@"fastGreeting")) {
        LFLog(@"forwardingTargetForSelector: redirected fastGreeting to LFFastForwardTarget");
        return [LFFastForwardTarget new];
    }
    return [super forwardingTargetForSelector:sel];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel {
    // 第三阶段的前半段：如果快速转发没处理，runtime 需要先拿到方法签名，
    // 才能把这次消息封装成 NSInvocation。
    if (sel == NSSelectorFromString(@"fullGreeting")) {
        LFLog(@"methodSignatureForSelector: synthesized signature for fullGreeting");
        return [LFFullForwardProxy instanceMethodSignatureForSelector:@selector(fullGreeting)];
    }
    return [super methodSignatureForSelector:sel];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    // 第三阶段的后半段：开发者可手动决定这条 invocation 转发给谁执行。
    if (invocation.selector == NSSelectorFromString(@"fullGreeting")) {
        LFLog(@"forwardInvocation: invoked LFFullForwardProxy for fullGreeting");
        [invocation invokeWithTarget:[LFFullForwardProxy new]];
        return;
    }
    [super forwardInvocation:invocation];
}

@end

@interface LFForwardingEntry : NSObject
- (NSString *)runDemo;
@end

@implementation LFForwardingEntry

- (NSString *)runDemo {
    LFResetLogs();

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    LFMessageReceiver *receiver = [LFMessageReceiver new];

    // 显式使用 objc_msgSend 发送三条不存在于 LFMessageReceiver 声明中的消息，
    // 便于完整走过 runtime 的三种补救路径。
    NSString *(*sendStringMessage)(id, SEL) = (NSString *(*)(id, SEL))objc_msgSend;

    NSString *dynamicResult = sendStringMessage(receiver, NSSelectorFromString(@"dynamicGreeting"));
    NSString *fastResult = sendStringMessage(receiver, NSSelectorFromString(@"fastGreeting"));
    NSString *fullResult = sendStringMessage(receiver, NSSelectorFromString(@"fullGreeting"));

    [lines addObject:@"message forwarding demo"];
    [lines addObject:[NSString stringWithFormat:@"1. resolveInstanceMethod -> %@", dynamicResult]];
    [lines addObject:[NSString stringWithFormat:@"2. forwardingTargetForSelector -> %@", fastResult]];
    [lines addObject:[NSString stringWithFormat:@"3. forwardInvocation -> %@", fullResult]];
    [lines addObject:@""];
    [lines addObject:@"runtime path logs:"];
    [lines addObjectsFromArray:LFRuntimeLogs];

    return [lines componentsJoinedByString:@"\n"];
}

@end
