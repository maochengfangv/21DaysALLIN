//
//  ViewController.m
//  Interview_OC
//
//  Created by maochengfang on 2026/7/22.
//

#import "ViewController.h"
#import "Person.h"
#import "LogHelper.h"
#import "Article.h"
#import <os/lock.h>
#import <pthread.h>
#import <QuartzCore/QuartzCore.h>

static const NSInteger kLockBenchmarkCount = 1000000;

#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - ⚙️ 辅助类 1: MySingleton (B3 dispatch_once 死锁演示)
@interface MySingleton : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedDeadlockVersion;  // ❌ 故意在 init 里重入 shared = 死锁
@end
@implementation MySingleton
+ (instancetype)sharedInstance {
    static MySingleton *instance; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[MySingleton alloc] init]; });
    return instance;
}
+ (instancetype)sharedDeadlockVersion {
    static MySingleton *instance; static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MySingleton alloc] _initDeadlockVersion];
    });
    return instance;
}
- (instancetype)init { self = [super init]; return self; }
// ❌ 故意在 init 内再次调用 sharedDeadlockVersion = 💀死锁
- (instancetype)_initDeadlockVersion {
    self = [super init];
    if (self) {
        NSLog(@"  💀 [死锁触发点] init内部 再次调用 sharedDeadlockVersion → 等once解锁 = 死锁!");
        [MySingleton sharedDeadlockVersion];  // ← 💀 递归重入 dispatch_once = 死锁
    }
    return self;
}
@end

#pragma mark - ⚙️ 辅助类 2: MessageFwdDemo (C1 消息转发3步演示)
@interface MessageFwdDemo : NSObject
// 注意：notExistMethod 没有任何声明和实现，调用时会走完整消息转发流程
@end
@interface FwdBackupTarget : NSObject
- (void)notExistMethod:(NSString *)msg;
@end
@implementation FwdBackupTarget
- (void)notExistMethod:(NSString *)msg {
    NSLog(@"  🎯 [第2步备用实现] FwdBackupTarget 收到: %@ ✅", msg);
}
@end
@implementation MessageFwdDemo

// 🧠 [消息转发 Step 1] 动态方法解析：询问类是否要动态添加这个方法的实现
//    返回 YES = runtime 认为方法已被加好，重新调 msgSend
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    NSLog(@"  [1/3] resolveInstanceMethod: 询问是否动态添加方法 %@", NSStringFromSelector(sel));
    if (sel == @selector(notExistMethod:)) {
        // 🧠 面试加分项：这里可以用 class_addMethod 动态加上 IMP；此处返回 NO 让流程继续到 forwardingTarget
        return NO;  // 返回 NO → 进入 Step 2
    }
    return [super resolveInstanceMethod:sel];
}

// 🧠 [消息转发 Step 2] 备援接收者：是否有别的对象能处理这个消息？(快速转发,不创建NSInvocation)
//    返回非 nil 对象 = runtime 把消息转发给该对象，最常用 性价比最高
- (id)forwardingTargetForSelector:(SEL)aSelector {
    NSLog(@"  [2/3] forwardingTargetForSelector: 询问是否有备援接收者处理 %@", NSStringFromSelector(aSelector));
    if (aSelector == @selector(notExistMethod:)) {
        FwdBackupTarget *backup = [FwdBackupTarget new];
        NSLog(@"  → 返回备用对象 %@ 承接调用", backup);
        return backup;  // ← ✅ 返回备用对象 = 到此为止，成功转发
    }
    return nil;  // 返回 nil → 进入 Step 3 (最重量级的完整转发)
}

// 🧠 [消息转发 Step 3] 完整消息转发：生成 NSInvocation，自己决定怎么处理(改变target/selector/参数)
//    如果这里也没实现 → doesNotRecognizeSelector: 直接 crash unrecognized selector
- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector {
    NSLog(@"  [3/3] methodSignatureForSelector: 生成方法签名进入完整转发 %@", NSStringFromSelector(aSelector));
    if (aSelector == @selector(notExistMethod:)) {
        // 手动返回一个合适的签名: v@:@ = void return, id self, SEL cmd, id arg
        return [NSMethodSignature signatureWithObjCTypes:"v@:@"];
    }
    return [super methodSignatureForSelector:aSelector];
}
- (void)forwardInvocation:(NSInvocation *)invocation {
    NSLog(@"  [3/3] forwardInvocation: 完整转发 %@", NSStringFromSelector(invocation.selector));
    // 这里可以改 target / 改参数 / 改 selector 自由发挥
    FwdBackupTarget *t = [FwdBackupTarget new];
    [invocation invokeWithTarget:t];
}
@end

#pragma mark - ⚙️ 辅助类 3: Person Category (C3 关联对象 Associated Object 演示)
@interface Person (Associated)
@property (nonatomic, strong) NSNumber *extTag;  // Category 加属性必须用 Associated
@property (nonatomic, copy) NSString *extName;
@end
static const void *kExtTagKey   = &kExtTagKey;
static const void *kExtNameKey  = &kExtNameKey;
@implementation Person (Associated)
- (void)setExtTag:(NSNumber *)extTag {
    // OBJC_ASSOCIATION_RETAIN_NONATOMIC = strong, nonatomic
    objc_setAssociatedObject(self, kExtTagKey, extTag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (NSNumber *)extTag {
    return objc_getAssociatedObject(self, kExtTagKey);
}
- (void)setExtName:(NSString *)extName {
    // OBJC_ASSOCIATION_COPY_NONATOMIC = copy, nonatomic
    objc_setAssociatedObject(self, kExtNameKey, extName, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
- (NSString *)extName {
    return objc_getAssociatedObject(self, kExtNameKey);
}
@end

#pragma mark - ⚙️ 辅助类 4: MethodSwizzleDemo (C2 Method Swizzling 坑演示)
@interface SwizzleDemo : NSObject
- (void)originalMethod;
+ (void)safeExchangeInstanceMethod:(SEL)origSel withMethod:(SEL)swizSel;
@end
@implementation SwizzleDemo
- (void)originalMethod { NSLog(@"  🔵 原始方法 originalMethod 调用"); }
- (void)swizzled_originalMethod { NSLog(@"  🟢 被交换后的方法: 先做埋点/统计 → 再递归调用'原方法'(此时已是交换过的 originalMethod IMP)"); [self swizzled_originalMethod]; }
// 🧠 面试最坑：原方法可能未实现 OR 仅父类实现，直接 method_exchange = 修改父类 method list 💀污染所有子类！
// 大厂标准安全思路：class_addMethod 原子占位 → 成功=本类没origM/继承父类 → class_replaceMethod 单独替换 swizSel IMP
//                 → 失败=本类有origM → 安全 method_exchangeImplementations
+ (void)safeExchangeInstanceMethod:(SEL)origSel withMethod:(SEL)swizSel {
    Method origM = class_getInstanceMethod(self, origSel);
    Method swizM = class_getInstanceMethod(self, swizSel);
    if (!swizM) { NSLog(@"  ⚠️ Swizzle 失败: swizSel %@ 不存在!", NSStringFromSelector(swizSel)); return; }
    const char *types = method_getTypeEncoding(swizM);

    // 🧠 [核心第 1 步] 尝试把 swizM 的 IMP 作为 origSel 的实现，加到『本类』的 method list 上
    //   成功 = YES → origSel 在 本类 method list 不存在：
    //       a) origM == nil      → 本类+父类都没实现
    //       b) origM 非nil        → origM 是父类方法表的指针！直接 exchange = 改父类=污染其他子类💀
    //   无论哪种，addMethod 成功后本类 origSel → swizIMP 的映射就『占坑』了，不会再碰到父类 method list
    BOOL didAdd = class_addMethod(self, origSel, method_getImplementation(swizM), types);

    if (didAdd) {
        // 🧠 [核心第 2 步 didAdd = YES] 把 swizSel 的 IMP 替换为『原本 origSel 应有的 IMP』
        //   origM != nil → 父类的 IMP，用户调用 swizzled 方法里 [self swizzled_xxx] 会走到父类原实现（等价 super）
        //   origM == nil → 原类+父类都没 IMP！不能传 method_getImplementation(swizM)（会递归），显式塞空 IMP 兜底
        IMP fallbackIMP = (IMP)imp_implementationWithBlock(^(id _self) {
            NSLog(@"  ⚠️ [Swizzle兜底空IMP] %@ 的 origSel %@ 本类+父类均未实现，走到空IMP",
                  NSStringFromClass(self), NSStringFromSelector(origSel));
        });
        IMP origOrNilIMP = origM ? method_getImplementation(origM) : fallbackIMP;
        const char *origTypes = origM ? method_getTypeEncoding(origM) : types;
        class_replaceMethod(self, swizSel, origOrNilIMP, origTypes);
    } else {
        // 🧠 [didAdd = NO] addMethod 失败 → 本类 method list 已经存在 origSel！
        //   此时 origM 100% 指向 self.methodLists 内部（不是父类的），exchange 才是安全的
        method_exchangeImplementations(origM, swizM);
    }
}
@end

@interface ViewController ()

@property (nonatomic, strong) Person *person;
@property (nonatomic, strong) Person *kvoPerson;
@property (nonatomic, strong) NSThread *workThread;

@property (nonatomic, assign) os_unfair_lock unfairLock;
@property (nonatomic, assign) pthread_mutex_t mutexLock;
@property (nonatomic, assign) pthread_mutex_t recursiveMutex;
@property (nonatomic, strong) NSLock *nsLock;
@property (nonatomic, strong) NSRecursiveLock *nsRecursiveLock;
@property (nonatomic, strong) NSConditionLock *conditionLock;
@property (nonatomic, strong) dispatch_semaphore_t semLock;
@property (nonatomic, strong) dispatch_semaphore_t semLimit;
@property (nonatomic, strong) dispatch_semaphore_t semSync;

@property (nonatomic, assign) NSInteger unsafeCounter;
@property (nonatomic, assign) NSInteger safeCounter;

// ====== 以下为新增面试 Demo 属性 ======
// Block & 内存管理
@property (nonatomic, copy) void (^retainCycleBlock)(void);
@property (nonatomic, strong) dispatch_source_t gcdTimer;

// 多读单写（Barrier 经典题）
@property (nonatomic, strong) dispatch_queue_t barrierQueue;
@property (nonatomic, strong) NSMutableDictionary *sharedData;

// Runtime 方法交换计数
@property (nonatomic, assign) NSInteger swizzleHookCount;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupLocks];
    
    // ====== 面试 Demo 演示入口（按需解除注释执行） ======
    
    // 1. 各类锁基本用法演示（推荐）
//    [self demonstrateLockBasicUsage];
    
    // 2. 多线程数据安全验证 (无锁 vs 有锁)
//    [self demonstrateThreadSafety];
    
    // 3. 性能对比测试 (百万级加解锁耗时)
//    [self demonstrateLockBenchmark];
    
    // 4. 可重入锁验证 (递归安全)
//    [self demonstrateRecursiveLock];
    
    // 5. Semaphore 限流 (并发数=3)
//    [self demonstrateSemaphoreLimit];
    
    // 6. Semaphore 线程同步栅栏 (async → sync)
//    [self demonstrateSemaphoreSync];
    
    // ====== ⚠️ 死锁演示：解除注释会阻塞线程，请单个调试 ======
    // 7. NSLock 重入死锁 (普通锁非可重入)
//    [self demonstrateNSLockDeadlock];
    // 8. Semaphore 重入死锁 (无所有权，重复wait死锁)
//    [self demonstrateSemaphoreDeadlock];
    // 9.经典 AB 锁交叉死锁
//    [self demonstrateCrossLockDeadlock];
    
    // ====== ✅ AB 死锁三大解决方案（推荐）：解除对应注释逐个验证） ======
    // 10. 方案1：加锁顺序全局一致（都先 A 后 B）
//    [self demonstrateFix1_LockOrder];
    // 11. 方案2：tryLock 超时回滚 + 随机退避重试
//    [self demonstrateFix2_TryLockTimeout];
    // 12. 方案3：一次性申请所有资源（银行家算法雏形）
//    [self demonstrateFix3_BankerAlgorithm];
    
    
    // ====== 🧠 新增：6大面试核心模块（按需解除注释执行） ======
    
    // ====== 【A. Block & 内存管理】 ======
    // A1. Block 三种类型（NSGlobalBlock / NSStackBlock / NSMallocBlock）
//    [self demonstrateBlockTypes];
    // A2. Block 循环引用 + 3 种解法（weak/strong dance / __block / NSBlockOperation）
//    [self demonstrateBlockRetainCycle];
    // A3. 属性关键字对比 (atomic/nonatomic/strong/weak/assign/copy)
//    [self demonstratePropertyKeywords];
    // A4. __weak vs __unsafe_unretained 最本质区别
//    [self demonstrateWeakVsUnsafeUnretained];
    // A5. AutoreleasePool 什么时候释放？（子线程手动创建 + 嵌套池）
//    [self demonstrateAutoreleasePool];
    
    // ====== 【B. GCD 进阶】 ======
    // B1. dispatch_barrier 多读单写（经典读写锁面试题）
//    [self demonstrateBarrierReadWrite];
    // B2. dispatch_group 多任务依赖（3 个并发任务都完成后回调）
//    [self demonstrateDispatchGroup];
    // B3. dispatch_once 单例 + 重入死锁陷阱（经典面试坑）
//    [self demonstrateDispatchOnceDeadlock];
    // B4. dispatch_source 定时器（比 NSTimer 准，不依赖 RunLoop）
//    [self demonstrateGCDTimer];
    
    // ====== 【C. ObjC Runtime】 ======
    // C1. 消息转发完整流程 3 步（resolve / forwardingTarget / methodSignature）
//    [self demonstrateMessageForwarding];
    // C2. Method Swizzling 方法交换 + 最容易踩的坑（原方法未实现导致崩溃）
    [self demonstrateMethodSwizzling];
    // C3. 关联对象 Associated Object（给 Category 添加属性的原理）
//    [self demonstrateAssociatedObject];
    
    // ====== 【D. 事件响应链 & 绘制】 ======
    // D1. hitTest:withEvent: 查找最佳响应者（扩大点击区域经典题）
    // 在本文件末尾有 explainHitTestAlgorithm 注释讲解
    
    // ====== 【E. KVO 底层】 ======
    // E1. KVO 的 isa-swizzling 本质（NSKVONotifying_XXX 动态子类）
//    [self demonstrateKVOIsaSwizzling];
    
    // ====== 【F. 单例设计】 ======
    // F1. 单例三种写法对比（加锁/once/atomic）
    //    // 1. 创建 Person 实例
    //    self.person = [[Person alloc] initWithName:@"张三" age:25];
    //
    //    // 2. 演示 KVC 的基本用法
    //    [self demonstrateBasicKVC];
    //
    //    // 3. 演示字典与模型互转
    //    [self demonstrateDictionaryModelConversion];
    //
    //    // 4. 演示动态赋值
    //    [self demonstrateDynamicAssignment];
    //
    //    // 5. 演示操作私有成员变量
    //    [self demonstratePrivateVariableAccess];
    //
    //    // 6. 演示配合 KVO 使用
    //    [self demonstrateKVOWithKVC];
    
    // 7. 演示中文打印解决方案
    //    [self demonstrateChineseLogging];
    
    // 8. 演示纯 KVC 字典转模型的缺陷
    //    [self demonstratePureKVCLimitations];
    //        [self shallowCopy];
    //    [self shallowMutlCopy];
    //    [self realDeepCopy];
    
    //    [self  deepCopyWithMutableElements];
    
    //    [self ress];
    //    [self subThreadDispatchAfter];
    //    [self subThreadTimer];
    //    [self subThreadPerformSelector];
    
    /*
     startWorkerThread
         → NSThread 启动
         → threadEntry: 添加 Port + run（RunLoop 死循环）
         → 子线程常驻 ✅

     scheduleDelayedTasks
         → performSelector:onThread: → 注册到 workerThread 的 RunLoop 上
         → 1秒后执行 task1 ✅
         → 3秒后执行 task2 ✅

     stopWorkerThread
         → CFRunLoopStop → threadEntry 的 run 返回
         → 线程退出 ✅
     */
    [self startWorkThread];
    [self scheduleDelayedTasks];
}

#pragma mark - 1. 启动常驻子线程

- (void)startWorkThread {
    self.workThread = [[NSThread alloc] initWithTarget:self selector:@selector(threadEntry) object:nil];
    self.workThread.name = @"Work";
    [self.workThread start];
}

- (void)threadEntry {
    
    @autoreleasepool {
        //关键 给runloop 添加一个source 防止它立刻提出
        [[NSRunLoop currentRunLoop] addPort:[NSPort port] forMode:NSDefaultRunLoopMode];
        [[NSRunLoop currentRunLoop] run]; //死循环，直到 CFRunLoopStop
    }
}



#pragma mark - 2. 发送延迟任务（无 Timer 循环引用）

- (void)scheduleDelayedTasks {
    // 方案1：performSelector:withObject:afterDelay: 必须在本线程 RunLoop 上调用
    // 所以先切到 workThread，在该线程上注册延迟任务
    [self performSelector:@selector(_scheduleOnWorkThread)
                 onThread:self.workThread
               withObject:nil
            waitUntilDone:NO];
}

- (void)_scheduleOnWorkThread {
    // 此时已经在 workThread 的 RunLoop 上下文中
    // 延迟 1 秒执行 task1
    [self performSelector:@selector(task1) withObject:nil afterDelay:1.0];
    // 延迟 3 秒执行 task2
    [self performSelector:@selector(task2) withObject:nil afterDelay:3.0];
    //延迟 5秒 退出子线程
    [self performSelector:@selector(stopWorkerThread) withObject:nil afterDelay:5.0];
}

- (void)task1 {
    NSLog(@"[线程:%@] 任务1执行", [NSThread currentThread]);
}

- (void)task2 {
    NSLog(@"[线程:%@] 任务2执行", [NSThread currentThread]);
}


#pragma mark - 3. 退出子线程

- (void)stopWorkerThread {
    [self performSelector:@selector(_exitThread)
                 onThread:self.workThread
               withObject:nil
            waitUntilDone:NO
                    modes:@[NSDefaultRunLoopMode]];
}

- (void)_exitThread {
    NSLog(@"[线程:%@]   RunLoop 即将停止", [NSThread currentThread]);
    CFRunLoopStop(CFRunLoopGetCurrent());
    NSLog(@"[线程:%@]   RunLoop 已停止, 线程即将退出", [NSThread currentThread]);
    self.workThread = nil;
}





#pragma mark -  演示 容器类拷贝 浅拷贝

- (void)shallowCopy {
    NSArray *original = @[@"A",@"B",@"C"];
    NSArray *shallowCopy = [original copy]; //新容器 元素指针相同
    
    // 容器地址不同
    NSLog(@"容器地址: %p vs %p", original, shallowCopy);  //  相同
    
    // 元素地址相同
    NSLog(@"元素地址: %p vs %p", original[0], shallowCopy[0]);  // 相同
}

#pragma mark -  演示 新可变容器，元素仍浅拷贝
- (void)shallowMutlCopy {
    
    NSArray *original = @[@"A",@"B",@"C"];
    NSMutableArray *mutableCopy = [original mutableCopy];
    // 容器地址不同
    NSLog(@"容器地址: %p vs %p", original, mutableCopy);  //  不相同
    
    // 元素地址相同
    NSLog(@"元素地址: %p vs %p", original[0], mutableCopy[0]);  // 相同
}

- (void)realDeepCopy {
    
    NSArray *original = @[@"A",@"B",@"C"];
    // 方法1：归档解档（要求元素实现 NSCoding 协议）
    NSArray *deepCopy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:original]];
    // 方法2：使用 copyItems
    NSArray *deepCopy1 = [[NSArray alloc] initWithArray:original copyItems:YES];
    // 方法3：手动递归遍历
    NSMutableArray *deepCopy2 = [NSMutableArray array];
    for (id obj in original) {
        [deepCopy2 addObject:[obj copy]];
    }
    
    // 容器地址不同
    NSLog(@"容器地址: %p VS deepCopy: %p VS deepCopy1: %p VS  deepCopy2:%p", original, deepCopy,deepCopy1,deepCopy2);  //  不相同
    
    // 元素地址相同
    NSLog(@"元素地址: %p VS %p VS %p VS %p", original[0], deepCopy1[0], deepCopy1[0], deepCopy2[0]);  // 相同
    
}

- (void)ress {
    
    NSString *str = @"A";
    NSString *copied = [str copy];
    NSLog(@"%p vs %p", str, copied);  // 相同！不可变对象 copy = retain
}

/**
 * 不依赖 RunLoop，线程销毁不影响已入队的延迟 block；
 * 底层基于 mach port 内核实现，稳定性高；
 * 延迟到点后在指定队列异步执行。
 */
- (void)subThreadDispatchAfter {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"子线程开始");
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
            NSLog(@"2秒延迟执行，依旧在子线程");
        });
    });
    
}

- (void)subThreadTimer {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 定时器加入DefaultMode，但线程执行完立刻销毁，RunLoop不存在
        NSLog(@"子线程开始");
        [NSTimer scheduledTimerWithTimeInterval:2 repeats:NO block:^(NSTimer * _Nonnull timer) {
                NSLog(@"执行!!!");
            }];
        // 必须开启RunLoop保持线程存活
        [[NSRunLoop currentRunLoop] run];
    });
}

- (void)subThreadPerformSelector {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSLog(@"子线程开始");
        [self performSelector:@selector(delayFunc) withObject:self afterDelay:2];
        // 必须开启RunLoop保持线程存活
        [[NSRunLoop currentRunLoop] run];
    });
}

- (void)delayFunc {
    NSLog(@"执行!!!");
}


- (void)deepCopyWithMutableElements {
    // 关键修改：元素改为 NSMutableString
    NSMutableString *a = [NSMutableString stringWithString:@"A"];
    NSMutableString *b = [NSMutableString stringWithString:@"B"];
    NSMutableString *c = [NSMutableString stringWithString:@"C"];
    
    NSArray *original = @[a, b, c];
    
    // 方法1：归档解档
    NSArray *deepCopy = [NSKeyedUnarchiver unarchiveObjectWithData:
                         [NSKeyedArchiver archivedDataWithRootObject:original]];
    
    // 方法2：copyItems:YES
    NSArray *deepCopy1 = [[NSArray alloc] initWithArray:original copyItems:YES];
    
    // 方法3：手动递归遍历
    NSMutableArray *deepCopy2 = [NSMutableArray array];
    for (id obj in original) {
        [deepCopy2 addObject:[obj copy]];
    }
    
    // 容器地址 — 不同
    NSLog(@"容器地址: %p VS %p VS %p VS %p",
          original, deepCopy, deepCopy1, deepCopy2);
    
    // 元素地址 — 现在不同了！
    NSLog(@"元素地址: %p VS %p VS %p VS %p",
          original[0], deepCopy[0], deepCopy1[0], deepCopy2[0]);
    
    // 验证：外部修改不影响副本
    [a appendString:@"（被篡改）"];
    NSLog(@"original[0] = %@", original[0]);     // "A（被篡改）"
    NSLog(@"deepCopy[0] = %@", deepCopy[0]);     // "A"  ✅ 不受影响
    NSLog(@"deepCopy1[0] = %@", deepCopy1[0]);   // "A"  ✅ 不受影响
    NSLog(@"deepCopy2[0] = %@", deepCopy2[0]);   // "A"  ✅ 不受影响
}


#pragma mark - 8. 演示纯 KVC 字典转模型的缺陷
- (void)demonstratePureKVCLimitations {
    NSLog(@"\n\n=== 8. 演示纯 KVC 字典转模型的缺陷 ===");
    
    NSDictionary *articleDict = @{
        @"title": @"KVC 缺陷分析",
        @"views": @12345,
        @"book": @{ // 嵌套模型
            @"bookName": @"Objective-C 编程之道",
            @"price": @99
        },
        @"authors": @[ // 数组模型
            @{ @"authorName": @"张三", @"age": @30 },
            @{ @"authorName": @"李四", @"age": @35 }
        ],
        @"publishDate": @"2026-07-22", // 字符串日期
        @"isHot": @"YES", // 字符串布尔值
        @"unknownKey": @"这个键模型中没有", // 未定义 key
        @"extraData": @{@"version": @"1.0"} // 多余的嵌套数据
    };
    
    NSLog(@"\n--- 原始字典数据 ---");
    [LogHelper prettyLogDictionary:articleDict label:@"原始 Article 字典"];
    
    // 尝试使用纯 KVC 进行转换
    Article *article = [[Article alloc] init];
    
    @try {
        [article setValuesForKeysWithDictionary:articleDict];
        NSLog(@"\n--- 纯 KVC 转换结果 ---");
        [LogHelper logObject:article withLabel:@"纯 KVC 转换后的 Article"];
        
        // 缺陷分析
        NSLog(@"\n--- 纯 KVC 缺陷分析 ---");
        NSLog(@"1. 嵌套模型 (book): 期望是 Book 对象，实际是 %@", [article.book class]);
        NSLog(@"   KVC 无法自动将字典转换为嵌套模型对象。");
        
        NSLog(@"2. 数组模型 (authors): 期望是 Author 对象数组，实际是 %@", [article.authors.firstObject class]);
        NSLog(@"   KVC 无法自动将字典数组转换为模型数组。");
        
        NSLog(@"3. 类型转换容错差 (views): 期望是 NSInteger，字典中是 NSNumber，KVC 自动处理了。");
        NSLog(@"   类型转换容错差 (publishDate): 期望是 NSString，字典中是 NSString，KVC 自动处理了。");
        NSLog(@"   类型转换容错差 (isHot): 期望是 BOOL，字典中是 NSString(\"YES\")，KVC 自动处理了。");
        NSLog(@"   ⚠️ 注意：KVC 对基本类型和 NSString 之间有一定容错，但对于自定义对象类型则无能为力。");
        
        NSLog(@"4. 无 key 校验易崩溃: 字典中包含 'unknownKey' 和 'extraData'，但 Article 模型中没有。");
        NSLog(@"   由于 Article 中实现了 setValue:forUndefinedKey:，所以这里没有崩溃，而是打印了警告。");
        NSLog(@"   如果 Article 没有实现 setValue:forUndefinedKey:，这里会直接崩溃。");
        
    } @catch (NSException *exception) {
        NSLog(@"\n--- 纯 KVC 转换发生异常 ---");
        NSLog(@"异常信息: %@", exception);
        NSLog(@"这通常发生在未实现 setValue:forUndefinedKey: 或类型转换失败时。");
    }
}

#pragma mark - 1. KVC 基本用法
- (void)demonstrateBasicKVC {
    NSLog(@"\n=== 1. KVC 基本用法演示 ===");
    // 使用 KVC 设置属性值
    [self.person setValue:@"Oliver" forKey:@"name"];
    [self.person setValue:@30 forKey:@"age"];
    
    NSString *name = [self.person valueForKey:@"name"];
    NSNumber *age = [self.person valueForKey:@"age"];
    NSLog(@"设置后: name=%@, age=%@", name, age);
    
    // 设置嵌套属性（如果 Person 有子对象）
    
    [self.person setValue:@"北京朝阳区" forKeyPath:@"address"];
    
    NSString *address = [self.person valueForKeyPath:@"address"];
    
    NSLog(@"设置后: address=%@", address);
    
    [self.person setValue:@"设置只读内容" forKey:@"readOnlyStr"];
    
    NSString *readOnlyStr = [self.person valueForKeyPath:@"readOnlyStr"];
    NSLog(@"设置后: readOnlyStr=%@", readOnlyStr);
    
    [self.person setValue:nil forKey:@"age"];
    
    NSLog(@"设置nil后: age=%@", [self.person valueForKey:@"age"]);
}

#pragma mark - 2. 字典与模型互转
- (void)demonstrateDictionaryModelConversion {
    NSLog(@"\n=== 2. 字典与模型互转演示 ===");
        
    // 2.1 字典转模型
    
    NSDictionary *personDict = @{
           @"name": @"王五",
           @"age": @28,
           @"address": @"上海市浦东新区",
           @"hobbies": @[@"篮球", @"游泳", @"阅读"]
       };
    Person *personFromDict = [[Person alloc] init];
    [personFromDict setValuesForKeysWithDictionary:personDict];
    NSLog(@"字典转模型结果: %@", personFromDict);
    
    // 2.2 模型转字典
    
    NSDictionary *modelToDict = [personFromDict dictionaryWithValuesForKeys:@[@"name", @"age", @"address", @"hobbies"]];
    NSLog(@"模型转字典结果: %@", modelToDict);
    
    // 2.3 处理字典中有但模型没有的键
        NSDictionary *extraDict = @{
            @"name": @"赵六",
            @"age": @35,
            @"unknownKey": @"这个键模型中没有",
            @"address": @"广州市天河区"
        };
        
        Person *personWithExtra = [[Person alloc] init];
        @try {
            [personWithExtra setValuesForKeysWithDictionary:extraDict];
        } @catch (NSException *exception) {
            NSLog(@"捕获异常: %@", exception);
            // 安全处理：实现 setValue:forUndefinedKey: 方法
        }
}

#pragma mark - 3. 动态赋值
- (void)demonstrateDynamicAssignment {
    NSLog(@"\n=== 3. 动态赋值演示 ===");
    // 3.1 动态设置属性
    NSArray *propertyNames = @[@"name",@"age",@"address"];
    NSArray *propertyValues = @[@"动态名称",@40,@"动态地址"];
    
    for (NSInteger i = 0; i < propertyNames.count; i++) {
        NSString *key = propertyNames[i];
        id value = propertyValues[i];
        [self.person setValue:value forKey:key];
    }
    NSLog(@"动态赋值后: %@", self.person);
    
    // 3.2 动态调用集合方法
    NSArray *newHobbies = @[@"编程",@"音乐",@"旅行"];
    NSMutableArray *hobbies = [self.person mutableArrayValueForKey:@"hobbies"];
    [hobbies addObjectsFromArray:newHobbies];
    NSLog(@"添加爱好后: %@", self.person.hobbies);
    
    // 3.3 使用 KVC 进行集合操作
    NSArray *allNames = @[self.person.name,@"测试1",@"测试2"];
    NSArray *uppercasedNames = [allNames valueForKeyPath:@"uppercaseString"];
    NSLog(@"集合操作 - 大写转换: %@",  [uppercasedNames description]);
}

#pragma mark - 4. 操作私有成员变量
- (void)demonstratePrivateVariableAccess {
    NSLog(@"\n=== 4. 操作私有成员变量演示 ===");
    
    // 4.1 访问私有成员变量
    NSString *privateVar = [self.person valueForKey:@"privateVar"];
    NSNumber *privateNumber = [self.person valueForKey:@"privateNumber"];
    NSLog(@"访问私有变量: privateVar=%@, privateNumber=%@", privateVar, privateNumber);

    // 4.2 修改私有成员变量
    NSLog(@"修改前私有变量: privateVar=%@, privateNumber=%@", privateVar, privateNumber);
    
    [self.person setValue:@"修改后的私有值" forKey:@"privateVar"];
    [self.person setValue:@200 forKey:@"privateNumber"];
    
    // 4.3 重新获取修改后的值
    NSString *updatedPrivateVar = [self.person valueForKey:@"privateVar"];
    NSNumber *updatedPrivateNumber = [self.person valueForKey:@"privateNumber"];
    
    NSLog(@"修改后私有变量: privateVar=%@, privateNumber=%@", updatedPrivateVar, updatedPrivateNumber);
    
    // 4.4 验证局部变量和重新获取的值是否不同
    NSLog(@"对比 - 局部变量旧值: privateVar=%@, privateNumber=%@", privateVar, privateNumber);
    NSLog(@"对比 - 重新获取新值: privateVar=%@, privateNumber=%@", updatedPrivateVar, updatedPrivateNumber);
    
    // 4.4 访问不存在的私有变量（会触发异常）
       @try {
           id unknownValue = [self.person valueForKey:@"nonExistentPrivateVar"];
           NSLog(@"不存在的变量: %@", unknownValue);
       } @catch (NSException *exception) {
           NSLog(@"访问不存在的私有变量异常: %@", exception);
       }
}

#pragma mark - 5. 配合 KVO 使用
- (void)demonstrateKVOWithKVC {
    NSLog(@"\n=== 5. 配合 KVO 使用演示 ===");
    // 5.1 创建用于 KVO 观察的对象
    self.kvoPerson = [[Person alloc] initWithName:@"KVO测试" age:20];
    // 5.2 添加 KVO 观察
    [self.kvoPerson addObserver:self forKeyPath:@"score" options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld context:nil];
    // 5.3 使用 KVC 触发 KVO
     NSLog(@"初始分数: %ld", (long)self.kvoPerson.score);
    
    // 通过 KVC 修改 score，会触发 KVO
    [self.kvoPerson setValue:@80 forKey:@"score"];
    NSLog(@"第一次修改后分数: %ld", (long)self.kvoPerson.score);
    
    // 再次修改
    [self.kvoPerson setValue:@90 forKey:@"score"];
    // 5.4 移除观察者
    [self.kvoPerson removeObserver:self forKeyPath:@"score"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if([keyPath isEqualToString:@"score"]) {
        NSNumber *oldValue = change[NSKeyValueChangeOldKey];
        NSNumber *newValue = change[NSKeyValueChangeNewKey];
        NSLog(@"KVO 触发 - %@: 从 %@ 变为 %@", keyPath, oldValue, newValue);
    }
}

- (void)dealloc {
    @try {
        [self.kvoPerson removeObserver:self forKeyPath:@"score"];
    } @catch (NSException *exception) {
    }
    
    [self stopWorkerThread];
    
    pthread_mutex_destroy(&_mutexLock);
    pthread_mutex_destroy(&_recursiveMutex);
}

#pragma mark - ========== 锁与信号量面试 Demo ==========

#pragma mark 0. 锁初始化
- (void)setupLocks {
    _unfairLock = OS_UNFAIR_LOCK_INIT;
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_NORMAL);
    pthread_mutex_init(&_mutexLock, &attr);
    pthread_mutexattr_destroy(&attr);
    
    pthread_mutexattr_t recAttr;
    pthread_mutexattr_init(&recAttr);
    pthread_mutexattr_settype(&recAttr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_init(&_recursiveMutex, &recAttr);
    pthread_mutexattr_destroy(&recAttr);
    
    self.nsLock = [[NSLock alloc] init];
    self.nsRecursiveLock = [[NSRecursiveLock alloc] init];
    self.conditionLock = [[NSConditionLock alloc] initWithCondition:0];
    self.semLock = dispatch_semaphore_create(1);
    self.semLimit = dispatch_semaphore_create(3);
    self.semSync = dispatch_semaphore_create(0);
}

#pragma mark 1. 各类锁基本用法演示
- (void)demonstrateLockBasicUsage {
    NSLog(@"\n\n======= 【1】各类锁基本用法演示 =======\n");
    
    // 1.1 os_unfair_lock (iOS10+，性能最优)
    NSLog(@"--- 1.1 os_unfair_lock ---");
    os_unfair_lock_lock(&_unfairLock);
    NSLog(@"os_unfair_lock: 已进入临界区");
    os_unfair_lock_unlock(&_unfairLock);
    NSLog(@"os_unfair_lock: 已退出临界区");
    
    // 1.2 pthread_mutex (POSIX 标准)
    NSLog(@"\n--- 1.2 pthread_mutex (NORMAL) ---");
    pthread_mutex_lock(&_mutexLock);
    NSLog(@"pthread_mutex: 已进入临界区");
    pthread_mutex_unlock(&_mutexLock);
    NSLog(@"pthread_mutex: 已退出临界区");
    
    // 1.3 NSLock (Foundation 封装)
    NSLog(@"\n--- 1.3 NSLock ---");
    [self.nsLock lock];
    NSLog(@"NSLock: 已进入临界区");
    [self.nsLock unlock];
    NSLog(@"NSLock: 已退出临界区");
    BOOL locked = [self.nsLock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    NSLog(@"NSLock tryLock 结果: %@ (此时未持有锁应=YES)", locked ? @"成功" : @"失败");
    if (locked) [self.nsLock unlock];
    
    // 1.4 @synchronized (语法糖，递归锁)
    NSLog(@"\n--- 1.4 @synchronized ---");
    @synchronized(self) {
        NSLog(@"@synchronized(self): 已进入临界区");
        @synchronized(self) {
            NSLog(@"@synchronized(self): 嵌套进入，天然可重入 ✅");
        }
    }
    
    // 1.5 dispatch_semaphore(1) 模拟互斥锁
    NSLog(@"\n--- 1.5 dispatch_semaphore(1) 模拟互斥锁 ---");
    dispatch_semaphore_wait(self.semLock, DISPATCH_TIME_FOREVER);
    NSLog(@"dispatch_semaphore(1): P操作成功，进入临界区");
    dispatch_semaphore_signal(self.semLock);
    NSLog(@"dispatch_semaphore(1): V操作成功，退出临界区");
    
    NSLog(@"\n======= 【1】基本用法演示完毕 ✅ =======\n");
}

#pragma mark 2. 多线程数据安全验证 (无锁 vs 有锁)
- (void)demonstrateThreadSafety {
    NSLog(@"\n\n======= 【2】多线程数据安全验证：无锁 vs 有锁 =======\n");
    
    NSUInteger threadCount = 10;
    NSUInteger addPerThread = 1000;
    
    // --- 2.1 无锁版本：数据竞争，结果大概率错误 ---
    NSLog(@"--- 2.1 无锁版本（会出现数据竞争） ---");
    self.unsafeCounter = 0;
    CFTimeInterval unsafeStart = CACurrentMediaTime();
    dispatch_group_t group = dispatch_group_create();
    for (NSUInteger i = 0; i < threadCount; i++) {
        dispatch_group_async(group, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            for (NSUInteger j = 0; j < addPerThread; j++) {
                self.unsafeCounter++;  // read-modify-write 非原子
            }
        });
    }
    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    CFTimeInterval unsafeCost = CACurrentMediaTime() - unsafeStart;
    NSLog(@"无锁结果: unsafeCounter = %ld （期望值=%ld）✅:%@",
          (long)self.unsafeCounter,
          (long)(threadCount * addPerThread),
          self.unsafeCounter == (threadCount * addPerThread) ? @"恰好正确(概率极低)" : @"❌ 出现数据丢失");
    NSLog(@"无锁耗时: %.3f ms", unsafeCost * 1000);
    
    // --- 2.2 加锁版本：os_unfair_lock 保护 ---
    NSLog(@"\n--- 2.2 加锁版本 (os_unfair_lock) ---");
    self.safeCounter = 0;
    CFTimeInterval safeStart = CACurrentMediaTime();
    dispatch_group_t group2 = dispatch_group_create();
    for (NSUInteger i = 0; i < threadCount; i++) {
        dispatch_group_async(group2, dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            for (NSUInteger j = 0; j < addPerThread; j++) {
                os_unfair_lock_lock(&self->_unfairLock);
                self.safeCounter++;
                os_unfair_lock_unlock(&self->_unfairLock);
            }
        });
    }
    dispatch_group_wait(group2, DISPATCH_TIME_FOREVER);
    CFTimeInterval safeCost = CACurrentMediaTime() - safeStart;
    NSLog(@"有锁结果: safeCounter = %ld （期望值=%ld）✅:%@",
          (long)self.safeCounter,
          (long)(threadCount * addPerThread),
          self.safeCounter == (threadCount * addPerThread) ? @"完全正确" : @"❌ 加锁也错了！");
    NSLog(@"有锁耗时: %.3f ms（加锁带来的开销）", safeCost * 1000);
    
    NSLog(@"\n======= 【2】线程安全验证完毕 ✅ =======\n");
}

#pragma mark 3. 性能对比测试 (百万次加解锁)
- (void)demonstrateLockBenchmark {
    NSLog(@"\n\n======= 【3】锁性能基准测试 (加解锁 %ld 次) =======\n", (long)kLockBenchmarkCount);
    
    NSMutableArray<NSDictionary *> *results = [NSMutableArray array];
    
    // 3.1 os_unfair_lock
    {
        CFTimeInterval start = CACurrentMediaTime();
        for (NSInteger i = 0; i < kLockBenchmarkCount; i++) {
            os_unfair_lock_lock(&_unfairLock);
            os_unfair_lock_unlock(&_unfairLock);
        }
        CFTimeInterval cost = CACurrentMediaTime() - start;
        [results addObject:@{@"name": @"os_unfair_lock", @"cost": @(cost)}];
        NSLog(@"os_unfair_lock    : 总耗时 %.3f ms | 单次 %.1f ns",
              cost * 1000, cost / kLockBenchmarkCount * 1e9);
    }
    
    // 3.2 pthread_mutex(NORMAL)
    {
        CFTimeInterval start = CACurrentMediaTime();
        for (NSInteger i = 0; i < kLockBenchmarkCount; i++) {
            pthread_mutex_lock(&_mutexLock);
            pthread_mutex_unlock(&_mutexLock);
        }
        CFTimeInterval cost = CACurrentMediaTime() - start;
        [results addObject:@{@"name": @"pthread_mutex", @"cost": @(cost)}];
        NSLog(@"pthread_mutex    : 总耗时 %.3f ms | 单次 %.1f ns",
              cost * 1000, cost / kLockBenchmarkCount * 1e9);
    }
    
    // 3.3 NSLock
    {
        CFTimeInterval start = CACurrentMediaTime();
        for (NSInteger i = 0; i < kLockBenchmarkCount; i++) {
            [self.nsLock lock];
            [self.nsLock unlock];
        }
        CFTimeInterval cost = CACurrentMediaTime() - start;
        [results addObject:@{@"name": @"NSLock", @"cost": @(cost)}];
        NSLog(@"NSLock           : 总耗时 %.3f ms | 单次 %.1f ns",
              cost * 1000, cost / kLockBenchmarkCount * 1e9);
    }
    
    // 3.4 NSRecursiveLock
    {
        CFTimeInterval start = CACurrentMediaTime();
        for (NSInteger i = 0; i < kLockBenchmarkCount; i++) {
            [self.nsRecursiveLock lock];
            [self.nsRecursiveLock unlock];
        }
        CFTimeInterval cost = CACurrentMediaTime() - start;
        [results addObject:@{@"name": @"NSRecursiveLock", @"cost": @(cost)}];
        NSLog(@"NSRecursiveLock  : 总耗时 %.3f ms | 单次 %.1f ns",
              cost * 1000, cost / kLockBenchmarkCount * 1e9);
    }
    
    // 3.5 @synchronized
    {
        CFTimeInterval start = CACurrentMediaTime();
        for (NSInteger i = 0; i < kLockBenchmarkCount; i++) {
            @synchronized(self) {}
        }
        CFTimeInterval cost = CACurrentMediaTime() - start;
        [results addObject:@{@"name": @"@synchronized", @"cost": @(cost)}];
        NSLog(@"@synchronized    : 总耗时 %.3f ms | 单次 %.1f ns",
              cost * 1000, cost / kLockBenchmarkCount * 1e9);
    }
    
    // 3.6 dispatch_semaphore(1)
    {
        CFTimeInterval start = CACurrentMediaTime();
        dispatch_semaphore_t sem = dispatch_semaphore_create(1);
        for (NSInteger i = 0; i < kLockBenchmarkCount; i++) {
            dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
            dispatch_semaphore_signal(sem);
        }
        CFTimeInterval cost = CACurrentMediaTime() - start;
        [results addObject:@{@"name": @"dispatch_semaphore(1)", @"cost": @(cost)}];
        NSLog(@"dispatch_sema(1) : 总耗时 %.3f ms | 单次 %.1f ns",
              cost * 1000, cost / kLockBenchmarkCount * 1e9);
    }
    
    // 排序输出性能排名
    [results sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"cost" ascending:YES]]];
    NSLog(@"\n--- 🏆 性能排名（快 → 慢） ---");
    [results enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL *stop) {
        NSLog(@"  %lu. %@  (%.1f ns/op)", (unsigned long)idx + 1, obj[@"name"],
              [obj[@"cost"] doubleValue] / kLockBenchmarkCount * 1e9);
    }];
    
    NSLog(@"\n======= 【3】性能基准测试完毕 ✅ =======\n");
}

#pragma mark 4. 可重入锁验证 (递归场景)
- (void)demonstrateRecursiveLock {
    NSLog(@"\n\n======= 【4】可重入锁验证：递归调用安全 =======\n");
    
    NSInteger depth = 5;
    
    // 4.1 NSRecursiveLock 可重入 ✅
    NSLog(@"--- 4.1 NSRecursiveLock 递归调用 (depth=%ld) ---", (long)depth);
    [self _recursiveMethodWithNSRecursiveLock:depth];
    NSLog(@"✅ NSRecursiveLock 递归成功，无死锁\n");
    
    // 4.2 @synchronized 可重入 ✅
    NSLog(@"--- 4.2 @synchronized 递归调用 (depth=%ld) ---", (long)depth);
    [self _recursiveMethodWithSynchronized:depth];
    NSLog(@"✅ @synchronized 递归成功，无死锁\n");
    
    // 4.3 pthread_mutex(RECURSIVE) 可重入 ✅
    NSLog(@"--- 4.3 pthread_mutex(RECURSIVE) 递归调用 (depth=%ld) ---", (long)depth);
    [self _recursiveMethodWithPthreadRecursive:depth];
    NSLog(@"✅ pthread_mutex(RECURSIVE) 递归成功，无死锁");
    
    NSLog(@"\n💡 对比：第 7 节演示了 NSLock 在同样递归下会死锁 ❌");
    NSLog(@"\n======= 【4】可重入锁验证完毕 ✅ =======\n");
}

- (void)_recursiveMethodWithNSRecursiveLock:(NSInteger)level {
    [self.nsRecursiveLock lock];
    if (level > 0) {
        NSLog(@"  NSRecursiveLock 进入第 %ld 层", (long)level);
        [self _recursiveMethodWithNSRecursiveLock:level - 1];
        NSLog(@"  NSRecursiveLock 返回第 %ld 层", (long)level);
    } else {
        NSLog(@"  🎯 NSRecursiveLock 抵达递归基 (level=0)");
    }
    [self.nsRecursiveLock unlock];
}

- (void)_recursiveMethodWithSynchronized:(NSInteger)level {
    @synchronized(self) {
        if (level > 0) {
            NSLog(@"  @synchronized 进入第 %ld 层", (long)level);
            [self _recursiveMethodWithSynchronized:level - 1];
            NSLog(@"  @synchronized 返回第 %ld 层", (long)level);
        } else {
            NSLog(@"  🎯 @synchronized 抵达递归基 (level=0)");
        }
    }
}

- (void)_recursiveMethodWithPthreadRecursive:(NSInteger)level {
    pthread_mutex_lock(&_recursiveMutex);
    if (level > 0) {
        NSLog(@"  pthread_mutex(R) 进入第 %ld 层", (long)level);
        [self _recursiveMethodWithPthreadRecursive:level - 1];
        NSLog(@"  pthread_mutex(R) 返回第 %ld 层", (long)level);
    } else {
        NSLog(@"  🎯 pthread_mutex(R) 抵达递归基 (level=0)");
    }
    pthread_mutex_unlock(&_recursiveMutex);
}

#pragma mark 5. Semaphore 限流 (并发数 = 3)
- (void)demonstrateSemaphoreLimit {
    NSLog(@"\n\n======= 【5】dispatch_semaphore 限流演示：最大并发=3 =======\n");
    NSLog(@"💡 场景：10 个任务，但最多同时只能有 3 个在执行（类似 NSOperationQueue maxConcurrentCount）");
    NSLog(@"🧠 面试考点：统一显式 QoS，避免 Thread Performance Checker 报优先级反转警告");
    NSLog(@"     ❌ 旧写法 dispatch_get_global_queue(0, 0) → QoS 不确定，sem wait 跨 QoS 等锁会触发警告");
    NSLog(@"     ✅ 修复：指定统一 QOS_CLASS_UTILITY 队列，所有 worker 同一优先级，彻底消除反转风险");
    NSLog(@"观察：每批只有 3 个『开始』，间隔 1 秒后一批『完成』+ 下一批『开始』\n");
    
    // 🧠 面试点：不要用 global_queue(0, 0)，0=QOS_CLASS_DEFAULT 会随调用方继承导致 QoS 不一致
    // semaphore 本身不支持『优先级继承协议』(不像 pthread_mutex 有 PTHREAD_PRIO_INHERIT)，
    // 一旦高 QoS 线程 wait 低 QoS 线程持有的 sem，就会产生优先级反转，TP C 必报
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    dispatch_semaphore_t limitSem = dispatch_semaphore_create(3);
    
    for (NSInteger i = 0; i < 10; i++) {
        dispatch_async(queue, ^{
            // QoS = UTILITY 工作线程内部 sem_wait，不会跨 QoS，无优先级反转 ✅
            dispatch_semaphore_wait(limitSem, DISPATCH_TIME_FOREVER);
            
            NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
            [fmt setDateFormat:@"HH:mm:ss.SSS"];
            NSString *ts = [fmt stringFromDate:[NSDate date]];
            NSLog(@"[%@] 🚀 任务 %02ld 开始执行", ts, (long)i);
            
            sleep(1);
            
            ts = [fmt stringFromDate:[NSDate date]];
            NSLog(@"[%@] ✅ 任务 %02ld 执行完成", ts, (long)i);
            
            dispatch_semaphore_signal(limitSem);
        });
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSLog(@"\n======= 【5】Semaphore 限流演示完毕 ✅ =======\n");
    });
}

#pragma mark 6. Semaphore 线程同步栅栏 (async → sync)
- (void)demonstrateSemaphoreSync {
    NSLog(@"\n\n======= 【6】dispatch_semaphore 线程同步栅栏 =======\n");
    NSLog(@"💡 场景：将异步回调『转』同步等待，常用在网络请求单元测试 / 启动任务串联\n");
    
    // 模拟：子线程发起"异步请求"，主线程阻塞等待回调
    dispatch_semaphore_t syncSem = dispatch_semaphore_create(0);
    __block NSString *resultData = nil;
    
    NSLog(@"[主线程] 发起异步请求，等待返回...");
    CFTimeInterval start = CACurrentMediaTime();
    
    // 🧠 面试点：同步栅栏场景下，主线程 (QoS=UserInitiated/Main) wait，
    // 子线程 signal。semaphore 无所有权 + 无优先级继承，严格说仍有反转风险。
    // 但这是『刻意的同步等待』语义，等同于 dispatch_sync，一般可接受。
    // 若要极致严谨，子线程至少提升至同等 QoS 或更高一档：
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSLog(@"[子线程(QoS=UserInitiated)] 模拟网络请求 (2秒耗时)...");
        sleep(2);
        resultData = @"{\"code\": 0, \"msg\": \"请求成功\"}";
        NSLog(@"[子线程] 请求完成，signal 唤醒主线程");
        dispatch_semaphore_signal(syncSem);
    });
    
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC));
    long waitResult = dispatch_semaphore_wait(syncSem, timeout);
    CFTimeInterval cost = CACurrentMediaTime() - start;
    
    if (waitResult == 0) {
        NSLog(@"[主线程] ✅ 等到结果 (耗时 %.1fs)：%@", cost, resultData);
    } else {
        NSLog(@"[主线程] ❌ 等待超时 (耗时 %.1fs)", cost);
    }
    
    // 演示 signal 与 wait 线程不同（semaphore 无所有权）
    NSLog(@"\n💡 额外验证：semaphore 没有『所有权』概念");
    NSLog(@"   NSLock 要求谁 lock 谁 unlock，semaphore 不需要：");
    NSLog(@"   上面的例子：子线程 signal，主线程 wait，完全合法 ✅");
    
    NSLog(@"\n======= 【6】Semaphore 同步演示完毕 ✅ =======\n");
}

#pragma mark ⚠️ 7. 死锁案例 - NSLock 重入死锁
- (void)demonstrateNSLockDeadlock {
    NSLog(@"\n\n======= 【⚠️7】死锁案例：NSLock 递归重入死锁 =======\n");
    NSLog(@"💡 原理：NSLock 是普通互斥锁，不支持可重入。同一线程连续 lock 两次，第二次永远等不到 unlock\n");
    NSLog(@"🔥 即将触发死锁... 执行后 Xcode 会卡住，可点击『暂停程序』查看调用栈\n");
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        [self _deadlockRecursiveWithNSLock:3];
    });
}

- (void)_deadlockRecursiveWithNSLock:(NSInteger)level {
    NSLog(@"  尝试 lock 进入 level=%ld", (long)level);
    [self.nsLock lock];
    NSLog(@"  ✅ lock 成功 level=%ld", (long)level);
    
    if (level > 0) {
        NSLog(@"  递归进入 level=%ld → 同线程再次 lock，死锁 💀", (long)(level - 1));
        [self _deadlockRecursiveWithNSLock:level - 1]; // 死锁点
    }
    
    [self.nsLock unlock];
    NSLog(@"  unlock 成功 level=%ld (不会到达这里)", (long)level);
}

#pragma mark ⚠️ 8. 死锁案例 - Semaphore 重入死锁
- (void)demonstrateSemaphoreDeadlock {
    NSLog(@"\n\n======= 【⚠️8】死锁案例：dispatch_semaphore 重入死锁 =======\n");
    NSLog(@"💡 原理：semaphore 天然不支持可重入，同线程连续 wait 两次（value=1 时），第二次 value=0 直接休眠\n");
    NSLog(@"🔥 即将触发死锁...\n");
    
    dispatch_semaphore_t deadSem = dispatch_semaphore_create(1);
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSLog(@"  [线程A] 第1次 wait，value=1→0，进入临界区");
        dispatch_semaphore_wait(deadSem, DISPATCH_TIME_FOREVER);
        
        NSLog(@"  [线程A] 做一些事情...");
        
        NSLog(@"  [线程A] 第2次 wait，value=0→休眠，死锁 💀 (没有任何人能 signal)");
        dispatch_semaphore_wait(deadSem, DISPATCH_TIME_FOREVER);
        
        dispatch_semaphore_signal(deadSem);
        dispatch_semaphore_signal(deadSem);
        NSLog(@"  ✅ 不会走到这里");
    });
}

#pragma mark ⚠️ 9. 死锁案例 - 经典 AB 锁交叉死锁
- (void)demonstrateCrossLockDeadlock {
    NSLog(@"\n\n======= 【⚠️9】死锁案例：经典 AB 锁交叉死锁 =======\n");
    NSLog(@"💡 原理：线程1 锁 A→等 B；线程2 锁 B→等 A。循环等待，谁都不释放。\n");
    NSLog(@"🔥 即将触发死锁...\n");
    
    NSLock *lockA = [[NSLock alloc] init];
    NSLock *lockB = [[NSLock alloc] init];
    
    dispatch_queue_t q1 = dispatch_queue_create("com.demo.thread1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t q2 = dispatch_queue_create("com.demo.thread2", DISPATCH_QUEUE_SERIAL);
    
    dispatch_async(q1, ^{
        NSLog(@"[线程1] 🔒 加锁 A (成功)");
        [lockA lock];
        NSLog(@"[线程1] 执行 A 区域逻辑...(睡 0.5 秒确保对方也锁上 B)");
        usleep(500000);
        NSLog(@"[线程1] 🔒 尝试加锁 B → 等待 lockB 释放 (被线程2持有) 💀");
        [lockB lock];      // 死锁点：等待线程2释放B
        NSLog(@"[线程1] ✅ 锁 B 成功 (不会到达)");
        [lockB unlock];
        [lockA unlock];
    });
    
    dispatch_async(q2, ^{
        NSLog(@"[线程2] 🔒 加锁 B (成功)");
        [lockB lock];
        NSLog(@"[线程2] 执行 B 区域逻辑...(睡 0.5 秒确保对方也锁上 A)");
        usleep(500000);
        NSLog(@"[线程2] 🔒 尝试加锁 A → 等待 lockA 释放 (被线程1持有) 💀");
        [lockA lock];      // 死锁点：等待线程1释放A
        NSLog(@"[线程2] ✅ 锁 A 成功 (不会到达)");
        [lockA unlock];
        [lockB unlock];
    });
    
    NSLog(@"💡 请看 Demo 10/11/12 对应三大解决方案 → 到 viewDidLoad 解除注释运行 ✅");
}

#pragma mark ✅ 10. AB死锁 方案1：加锁顺序全局一致（都先 A 后 B）
- (void)demonstrateFix1_LockOrder {
    NSLog(@"\n\n======= 【✅10】方案1：加锁顺序全局一致（都先 A 后 B） =======\n");
    NSLog(@"💡 原理：破坏『循环等待』四个必要条件之一。所有线程统一 先锁A再锁B，环路被切断，永远不会死锁\n");
    NSLog(@"🧠 面试考点：死锁四必要条件 = 互斥 / 持有并等待 / 不可抢占 / 循环等待 → 本方案破坏『循环等待』\n");
    
    NSLock *lockA = [[NSLock alloc] init];
    NSLock *lockB = [[NSLock alloc] init];
    lockA.name = @"LockA";
    lockB.name = @"LockB";
    
    dispatch_queue_t q1 = dispatch_queue_create("com.demo.thread1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t q2 = dispatch_queue_create("com.demo.thread2", DISPATCH_QUEUE_SERIAL);
    dispatch_group_t group = dispatch_group_create();
    
    // 线程1：严格 A → B
    dispatch_group_async(group, q1, ^{
        NSLog(@"[线程1] 🔒 按协议：先锁 A");
        [lockA lock];
        NSLog(@"[线程1] ✅ 锁 A 成功，执行 A 逻辑 (0.3s)");
        usleep(300000);
        
        NSLog(@"[线程1] 🔒 按协议：再锁 B");
        [lockB lock];
        NSLog(@"[线程1] ✅ 锁 B 成功，同时持有 A+B 临界区 (0.2s)");
        usleep(200000);
        
        NSLog(@"[线程1] 🔓 解锁 B → A");
        [lockB unlock];
        [lockA unlock];
        NSLog(@"[线程1] 🎉 完整执行完毕，无死锁 ✅\n");
    });
    
    // 线程2：也严格 A → B（与 Demo 9 的致命区别！不再先 B 后 A）
    dispatch_group_async(group, q2, ^{
        NSLog(@"[线程2] 🔒 按协议：先锁 A");
        [lockA lock];
        NSLog(@"[线程2] ✅ 锁 A 成功，执行 A 逻辑 (0.3s)");
        usleep(300000);
        
        NSLog(@"[线程2] 🔒 按协议：再锁 B");
        [lockB lock];
        NSLog(@"[线程2] ✅ 锁 B 成功，同时持有 A+B 临界区 (0.2s)");
        usleep(200000);
        
        NSLog(@"[线程2] 🔓 解锁 B → A");
        [lockB unlock];
        [lockA unlock];
        NSLog(@"[线程2] 🎉 完整执行完毕，无死锁 ✅\n");
    });
    
    // 主线程等两个线程跑完，打印总结
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"🏆 方案1总结：加锁顺序全局一致（全链路强制 LockA → LockB）");
        NSLog(@"   ✅ 优点：零额外开销、性能无损、语义最清晰");
        NSLog(@"   ❌ 缺点：架构约束强，跨团队/跨模块难统一；锁多了排序维护成本陡升");
        NSLog(@"   🎯 适用：锁数量 < 5、团队小、全链路可控（如组件内私有锁）");
    });
}

#pragma mark ✅ 11. AB死锁 方案2：tryLock 超时回滚 + 随机退避重试
- (void)demonstrateFix2_TryLockTimeout {
    NSLog(@"\n\n======= 【✅11】方案2：tryLock 超时回滚 + 随机退避重试 =======\n");
    NSLog(@"💡 原理：破坏『不可抢占』条件。拿不到下一把锁就全部释放、等一会儿重试，不会一直『持有并等待』卡死\n");
    NSLog(@"🧠 面试考点：与方案1互补。lockBeforeDate: 返回 NO 说明获取失败；必须按『倒序释放已持有的锁』，避免部分持有\n");
    
    NSLock *lockA = [[NSLock alloc] init];
    NSLock *lockB = [[NSLock alloc] init];
    
    const NSInteger kMaxRetry = 5;
    const NSTimeInterval kLockTimeout = 0.2; // 单锁超时时间
    
    // 封装：原子执行「事务逻辑」— 返回 YES=完成，NO=需要重试
    BOOL (^transferWorker)(NSString *, NSLock *, NSLock *) = ^BOOL(NSString *threadName, NSLock *firstLock, NSLock *secondLock) {
        // Step 1：锁第一把
        if (![firstLock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:kLockTimeout]]) {
            NSLog(@"[%@] ⚠️ 锁 %@ 超时，本次放弃 (无持有 → 直接重试)", threadName, firstLock.name ?: @"firstLock");
            return NO;
        }
        NSLog(@"[%@] ✅ 锁 第一把 成功", threadName);
        usleep(100000); // 模拟临界区耗时，放大冲突
        
        // Step 2：锁第二把 → 失败要回滚第一把！
        if (![secondLock lockBeforeDate:[NSDate dateWithTimeIntervalSinceNow:kLockTimeout]]) {
            NSLog(@"[%@] ⚠️ 锁 第二把 超时 → 🔙 回滚释放第一把（关键！不能持锁退出)", threadName);
            [firstLock unlock];  // 🧠 不可遗漏：倒序释放，否则下次才能继续前进
            return NO;
        }
        NSLog(@"[%@] ✅ 锁 第二把 成功 → 进入双锁完整临界区", threadName);
        usleep(200000);
        
        // Step 3：业务完成，倒序解锁（与加锁相反）
        [secondLock unlock];
        [firstLock unlock];
        NSLog(@"[%@] 🎉 业务完成，双锁已释放 ✅\n", threadName);
        return YES;
    };
    
    dispatch_queue_t q1 = dispatch_queue_create("com.demo.thread1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t q2 = dispatch_queue_create("com.demo.thread2", DISPATCH_QUEUE_SERIAL);
    dispatch_group_t group = dispatch_group_create();
    
    // 线程1：顺序 A→B（故意 A→B
    dispatch_group_async(group, q1, ^{
        lockA.name = @"A"; lockB.name = @"B";
        for (NSInteger attempt = 1; attempt <= kMaxRetry; attempt++) {
            NSLog(@"[线程1] 🔁 第 %ld/%ld 次尝试 (A→B)", (long)attempt, (long)kMaxRetry);
            BOOL done = transferWorker(@"线程1", lockA, lockB);
            if (done) return;
            // 随机退避：1~5 ms（面试点：避免『活锁』—— 两个线程同节奏互相让导致都跑不完）
            useconds_t sleepUs = (arc4random() % 5 + 1) * 1000;
            NSLog(@"[线程1] 💤 退避 %lu μs 后重试 (防活锁)", (unsigned long)sleepUs);
            usleep(sleepUs);
        }
        NSLog(@"[线程1] ❌ 超过最大重试次数，上报业务失败");
    });
    
    // 线程2：顺序 B→A（故意与线程1相反，最容易触发死锁 → 验证方案2兜底能力
    dispatch_group_async(group, q2, ^{
        for (NSInteger attempt = 1; attempt <= kMaxRetry; attempt++) {
            NSLog(@"[线程2] 🔁 第 %ld/%ld 次尝试 (B→A)", (long)attempt, (long)kMaxRetry);
            BOOL done = transferWorker(@"线程2", lockB, lockA);
            if (done) return;
            useconds_t sleepUs = (arc4random() % 5 + 1) * 1000;
            NSLog(@"[线程2] 💤 退避 %lu μs 后重试 (防活锁)", (unsigned long)sleepUs);
            usleep(sleepUs);
        }
        NSLog(@"[线程2] ❌ 超过最大重试次数，上报业务失败");
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"🏆 方案2总结：tryLock 超时 + 倒序释放回滚 + 随机退避");
        NSLog(@"   ✅ 优点：不要求全局锁顺序；跨团队/遗留代码接入成本低（局部即可生效");
        NSLog(@"   ✅ 防止活锁（Livelock）关键：『随机退避』而非固定间隔，否则同时重试还是撞车");
        NSLog(@"   ❌ 缺点：性能有折损（超时空等+重试）；极端情况下重试次数用尽仍会失败需上层兜底");
        NSLog(@"   🧠 面试陷阱：只 tryLock 第二把失败后，务必『倒序释放所有已持锁』= 核心，否则依旧会发生部分持有导致的伪死锁");
        NSLog(@"   🎯 适用：跨模块/遗留系统、加锁顺序无法统一、冲突概率低且有重试语义的场景");
    });
}

#pragma mark ✅ 12. AB死锁 方案3：一次性申请所有资源（银行家算法雏形）
- (void)demonstrateFix3_BankerAlgorithm {
    NSLog(@"\n\n======= 【✅12】方案3：一次性申请所有资源（银行家算法雏形） =======\n");
    NSLog(@"💡 原理：同时破坏『持有并等待』+『循环等待』两个条件。");
    NSLog(@"   要么一次性原子性拿到所有需要的锁，要么一把都不拿 sleep 重试，不存在『拿了一半等另一半』的状态\n");
    NSLog(@"🧠 面试考点：Dijkstra 银行家算法的极简版 —— 预检查『安全序列』；此处用一把全局 gate 模拟『原子批申请』\n");
    
    // 🔐 『资源管理中心』：所有锁的『原子申请/释放』都必须通过 gateLock 串行化
    // 这是方案3的灵魂：没有 gate，检查与拿锁之间会有 TOCTOU 竞态
    NSLock *gateLock = [[NSLock alloc] init];
    NSLock *resA = [[NSLock alloc] init];
    NSLock *resB = [[NSLock alloc] init];
    
    // 『资源状态』：true=已被占用，模拟『银行家算法 - 已分配矩阵』
    __block BOOL resAHeld = NO;
    __block BOOL resBHeld = NO;
    const NSInteger kMaxPoll = 20;
    
    // 封装：原子性『一次性申请 A+B』 成功=YES 失败=NO（全程无任何持锁退出）
    BOOL (^tryAcquireAll)(void) = ^BOOL{
        [gateLock lock];  // 『预检查 + 分配』必须原子进入 gate
        // 🧠 关键：只有当两个资源 ALL 空闲时才真正去 lock 它们
        // 若有一个忙 → 直接返回，全程不持有任何业务锁 → 破坏持有并等待
        if (resAHeld || resBHeld) {
            NSLog(@"  [资源中心] 🚫 当前资源繁忙 (A=%d B=%d) → 本次一把都不拿", resAHeld, resBHeld);
            [gateLock unlock];
            return NO;
        }
        // 预检查通过 → 真正锁两个锁；在 gate 内顺序执行，保证『一次性完成』原子性
        [resA lock]; resAHeld = YES;
        [resB lock]; resBHeld = YES;
        NSLog(@"  [资源中心] ✅ 原子分配 A+B 一次性分配成功");
        [gateLock unlock];
        return YES;
    };
    
    void (^releaseAll)(NSString *) = ^(NSString *who){
        [gateLock lock];
        [resA unlock]; resAHeld = NO;
        [resB unlock]; resBHeld = NO;
        NSLog(@"  [%@] ♻️ A+B 一次性释放完成", who);
        [gateLock unlock];
    };
    
    dispatch_queue_t q1 = dispatch_queue_create("com.demo.thread1", DISPATCH_QUEUE_SERIAL);
    dispatch_queue_t q2 = dispatch_queue_create("com.demo.thread2", DISPATCH_QUEUE_SERIAL);
    dispatch_group_t group = dispatch_group_create();
    
    // 线程1：声明需要 A+B（不管内部顺序，批申请）
    dispatch_group_async(group, q1, ^{
        NSLog(@"[线程1] 📝 声明：本次事务需要资源 A + B，到资源中心申请");
        for (NSInteger i = 1; i <= kMaxPoll; i++) {
            BOOL ok = tryAcquireAll();
            if (ok) break;
            NSLog(@"[线程1] 💤 申请失败，轮询等待 (%ld/%ld) 10ms", (long)i, (long)kMaxPoll);
            usleep(10000);
        }
        NSLog(@"[线程1] ✅ 进入双锁临界区执行 (0.3s)");
        usleep(300000);
        releaseAll(@"线程1");
        NSLog(@"[线程1] 🎉 事务完成 ✅\n");
    });
    
    // 线程2：也声明需要 A+B（故意与线程1在同一时刻竞争，验证无死锁
    dispatch_group_async(group, q2, ^{
        NSLog(@"[线程2] 📝 声明：本次事务需要资源 A + B，到资源中心申请");
        for (NSInteger i = 1; i <= kMaxPoll; i++) {
            BOOL ok = tryAcquireAll();
            if (ok) break;
            NSLog(@"[线程2] 💤 申请失败，轮询等待 (%ld/%ld) 10ms", (long)i, (long)kMaxPoll);
            usleep(10000);
        }
        NSLog(@"[线程2] ✅ 进入双锁临界区执行 (0.3s)");
        usleep(300000);
        releaseAll(@"线程2");
        NSLog(@"[线程2] 🎉 事务完成 ✅\n");
    });
    
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{
        NSLog(@"🏆 方案3总结：资源中心 gate 原子性一次性申请所有资源（银行家算法雏形）");
        NSLog(@"   ✅ 优点：彻底消除持有并等待，无死锁、无活锁；线程不需要知道对方存在");
        NSLog(@"   ✅ 面试加分：TOCTOU 问题必须用 gateLock 把『预检查+分配』包成原子，否则 check 到 lock 间隙被别人抢走会误判");
        NSLog(@"   ❌ 缺点：gate 成为性能瓶颈（全局串行）；粗粒度，极端情况并发会饥饿 资源多了银行家安全检查复杂度 O(m·n²)");
        NSLog(@"   🎯 适用：数据库行锁/分布式锁（如 Redis Redlock）、资源数固定且少、需要严格『全有或全无』语义的事务性场景");
    });
}

#pragma mark - ========== 🧠【A. Block & 内存管理】 ==========

#pragma mark A1. Block 三种类型 (Global / Stack / Malloc)
- (void)demonstrateBlockTypes {
    NSLog(@"\n\n======= 【A1】Block 三种存储类型 =======\n");
    NSLog(@"🧠 面试考点：Block 本质是『封装了函数调用 + 捕获变量』的结构体对象，分 3 类存放在不同区域");
    NSLog(@"   关键：__block 会将变量拷贝到堆上，实现 block 内外修改同一变量");
    
    // --- 类型 1：NSGlobalBlock（全局区，不捕获外部变量 或 只捕获静态/全局变量） ---
    void (^globalBlock)(void) = ^{ NSLog(@"  我没有捕获外部 auto 变量"); };
    NSLog(@"[A1-1] 无捕获 → %@ (地址=%p)\n", NSStringFromClass([globalBlock class]), globalBlock);
    
    // --- 类型 2：NSStackBlock（栈区，MRC 下才直接出现；ARC 下编译器一般自动 copy 到堆） ---
    // 🧠 面试考点：ARC 下『直接打印』通常会看到是 MallocBlock，因为编译器自动 copy 了；
    //   但把 block 直接作为参数传给不 copy 的方法（如 performSelector）仍可能是栈 block，出栈野指针崩溃！
    int a = 10;
    void (^stackBlock)(void) = ^{ NSLog(@"  捕获了局部变量 a=%d", a); };
    NSLog(@"[A1-2] 捕获 auto 局部变量 → %@ (地址=%p)\n", NSStringFromClass([stackBlock class]), stackBlock);
    
    // --- 类型 3：NSMallocBlock（堆区，栈 block 被 copy 后） ---
    void (^mallocBlock)(void) = [stackBlock copy];
    NSLog(@"[A1-3] stackBlock 被 copy → %@ (地址=%p)\n", NSStringFromClass([mallocBlock class]), mallocBlock);
    
    // --- __block 关键字演示：允许 block 内修改外部 auto 变量 ---
    __block NSInteger modifyCount = 0;
    void (^__block blockDemo)(void) = ^{
        modifyCount++;  // 没有 __block 这里编译报错！ Variable is not assignable (missing __block type specifier)
        NSLog(@"  [A1-4] __block 变量在 block 内部修改: modifyCount=%ld", (long)modifyCount);
    };
    blockDemo();
    NSLog(@"  [A1-4] block 执行后, 外部 modifyCount 同步更新为: %ld ✅\n", (long)modifyCount);
    
    NSLog(@"💡 记忆口诀：不捕全局(Global)，捕获局部先栈(Stack)再堆(Malloc)；栈 copy = 堆\n");
    NSLog(@"======= 【A1】Block 类型演示完毕 ✅ =======\n");
}

#pragma mark A2. Block 循环引用 + 3 种标准解法
- (void)demonstrateBlockRetainCycle {
    NSLog(@"\n\n======= 【A2】Block 循环引用 + 3 种解法 =======\n");
    NSLog(@"🧠 面试考点：self → block(copy到堆) → 捕获self → 闭环 = 经典循环引用！");
    
    // --- ❌ 错误写法：直接在 block 内引用 self，造成循环引用 --- 
    //    self.retainCycleBlock = ^{ NSLog(@"  [❌] 直接捕获 self = %p", self); };
    //    NSLog(@"  [❌] self(%p) -> retainCycleBlock -> 捕获self -> 循环引用!", self);
    
    // --- ✅ 解法 1：__weak + __strong dance（最常用，推荐写法） ---
    NSLog(@"\n--- 解法 1: __weak self + __strong self 防止中途释放 ---");
    __weak typeof(self) weakSelf = self;
    self.retainCycleBlock = ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { NSLog(@"    strongSelf 为 nil，说明 self 已被释放，提前 return"); return; }
        NSLog(@"    strongSelf 安全访问: self = %p", strongSelf);
    };
    self.retainCycleBlock();
    NSLog(@"  ✅ 解法 1: weak/strong dance 无循环引用");
    NSLog(@"  🧠 为何要 strong？weak 在执行中可能被置 nil（如 AFN 回调中途页面 pop），strong 保证一次执行内生命周期一致");
    
    // --- ✅ 解法 2：__block 变量（MRC 时代常用，ARC 下需手动置 nil 打破循环） ---
    NSLog(@"\n--- 解法 2: __block + 手动 break（ARC 下必须在 block 末尾显式置 nil） ---");
    __block ViewController *blockSelf = self;  // block 捕获 blockSelf 指针（在堆上）
    self.retainCycleBlock = ^{
        NSLog(@"    __block blockSelf = %p", blockSelf);
        // 🧠 面试坑：ARC 下 __block 会 retain 对象！必须执行一次以下语句才能打破：
        blockSelf = nil;  // ← 关键！不执行这行 = 仍循环引用（MRC 下 __block 不会 retain）
    };
    self.retainCycleBlock();
    NSLog(@"  ✅ 解法 2: __block + block内置nil 打破引用环");
    NSLog(@"  🧠 面试对比：MRC vs ARC 下 __block 的行为差异 = MRC 不retain，ARC 默认 retain!");
    
    // --- ✅ 解法 3：显式传参（把 self 当参数传入，不捕获） ---
    NSLog(@"\n--- 解法 3: 把 self 当参数传入 block，不发生捕获 ---");
    void (^paramBlock)(ViewController *) = ^(ViewController *vc) {
        NSLog(@"    传参 vc = %p，不形成捕获", vc);
    };
    paramBlock(self);
    NSLog(@"  ✅ 解法 3: 参数传递 = 无捕获 → 无循环引用（NSOperation/NSURLSession API 天然支持）");
    
    // 清理
    self.retainCycleBlock = nil;
    NSLog(@"\n======= 【A2】Block 循环引用演示完毕 ✅ =======\n");
}

#pragma mark A3. 属性关键字对比 (最常问的 copy/strong/assign/weak/atomic)
- (void)demonstratePropertyKeywords {
    NSLog(@"\n\n======= 【A3】属性关键字对比：copy vs strong vs assign vs weak vs atomic =======\n");
    NSLog(@"🧠 这是 iOS 一面最高频题，背熟下表 + 以下运行时验证！");
    
    // --- 核心 1: 为什么 NSString/NSArray/NSDictionary 用 copy 而不是 strong? ---
    NSMutableString *mutableName = [NSMutableString stringWithString:@"张三"];
    
    // 模拟 strong 语义：直接赋值 = 指针拷贝，外部修改会影响内部
    Person *pStrong = [[Person alloc] init];
    pStrong.name = mutableName;     // 即使声明是 copy，运行时都会 copy 一份不可变副本
    [mutableName appendString:@"(被篡改)"];
    NSLog(@"[copy] 外部 mutableName=%@  →  Person.name=%@  ✅ copy 关键字保护了内部不受外部篡改",
          mutableName, pStrong.name);
    
    // 🧠 面试点：如果把 name 声明成 strong，那么 mutableName 被修改时，p.name 会跟着变（指向同一对象）
    //   所以：『有可变子类的不可变类属性』必须用 copy = NSStr/NSArr/NSDict/NSBlock etc.
    
    // --- 核心 2: assign 基本不会用在对象上，否则野指针崩溃 --- 
    // 声明 assign 的对象属性：dealloc 后指针不会自动置 nil，悬垂指针访问 = EXC_BAD_ACCESS
    NSLog(@"\n[assign vs weak 本质区别表]");
    NSLog(@"  ┌──────────────┬─────────────────────┬──────────────────────────┐");
    NSLog(@"  │   关键字      │   引用计数变化        │    对象销毁后指针行为        │");
    NSLog(@"  ├──────────────┼─────────────────────┼──────────────────────────┤");
    NSLog(@"  │   strong     │   retain +1         │    不销毁(自己持有)         │");
    NSLog(@"  │   weak       │   不变（不 retain）   │    自动置 nil ⭐️          │");
    NSLog(@"  │   assign     │   不变（不 retain）   │    悬垂指针 → 野指针崩溃     │");
    NSLog(@"  │   copy       │   不可变副本 +1       │    不销毁(自己持有副本)      │");
    NSLog(@"  └──────────────┴─────────────────────┴──────────────────────────┘");
    NSLog(@"  🧠 用途：assign 仅用于基本类型(int/NSInteger/CGFloat)等非对象；delegate 必须 weak");
    
    // --- 核心 3: atomic 为什么不常用？ ---
    NSLog(@"\n[atomic vs nonatomic 本质]");
    NSLog(@"  atomic   : setter/getter 加自旋锁(os_unfair_lock)，保证『单个属性读写原子』→ 慢 10~20x");
    NSLog(@"  nonatomic: 不加锁 → 快，iOS 项目几乎全局 nonatomic");
    NSLog(@"  🧠 面试陷阱：atomic ≠ 线程安全！它只是保证 self.obj = A 和 B = self.obj 是原子的；");
    NSLog(@"     但 self.obj.prop = xxx  /  [self.array addObject:xxx] 这种复合操作 atomic 不管，");
    NSLog(@"     真实项目要线程安全必须自己加锁 (见你之前的 Demo2 线程安全)");
    
    NSLog(@"\n======= 【A3】属性关键字演示完毕 ✅ =======\n");
}

#pragma mark - ========== 🧠【C. ObjC Runtime】 ==========

#pragma mark C1. 消息转发完整流程 3 步
- (void)demonstrateMessageForwarding {
    NSLog(@"\n\n======= 【C1】消息转发完整流程 3 步（最完整 Demo】 =======\n");
    NSLog(@"🧠 面试必背：objc_msgSend 找方法找不到实现时，进入消息转发 3 步链（由轻到重）:");
    NSLog(@"  Step① resolveInstanceMethod:  → 本类动态添加方法IMP（最轻量 推荐用它加方法）");
    NSLog(@"  Step② forwardingTargetForSelector: → 换个对象处理（快速转发，无NSInvocation开销极小 最常用）");
    NSLog(@"  Step③ methodSignature + forwardInvocation: → 生成NSInvocation自由改（开销大 完整转发");
    NSLog(@"  全失败→ doesNotRecognizeSelector  💀 崩溃 unrecognized selector");
    NSLog(@"  ");
    
    MessageFwdDemo *demo = [MessageFwdDemo new];
    NSLog(@"🚀 调用一个本类完全没有实现的方法 → 触发完整 3 步消息转发链...\n");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    // performSelector:withObject: 内部同样走 objc_msgSend → 消息转发链路，对面试演示完全等价
    // 用 clang diagnostic push/pop 屏蔽 performSelector 可能不存在方法的 warning，因为我们就是故意不实现让它走转发
    [demo performSelector:@selector(notExistMethod:) withObject:@"Hello Runtime 消息转发测试"];
#pragma clang diagnostic pop
    
    NSLog(@"\n🏆 面试总结：3步转发的选型建议  ");
    NSLog(@"  · 90% 场景用 resolveInstanceMethod: 加IMP（最快，动态解析）最");
    NSLog(@"  · 多对象代理/MulticastDelegate协议用 forwardingTarget 性能好");
    NSLog(@"  · 复杂重写参数/变方法/变形参 NSInvocation 用第三步forwardInvocation");
    NSLog(@"  附加坑点：第三步 method签名不对会 crash，v@:@ 表示 void(id,SEL,id) ");
    NSLog(@"\n======= 【C1】消息转发演示完毕 ✅ =======\n");
}

#pragma mark C2. Method Swizzling 方法交换 + 最大坑（原方法未实现崩溃）
- (void)demonstrateMethodSwizzling {
    NSLog(@"\n\n======= 【C2】Method Swizzling + 最大安全写法 =======\n");
    NSLog(@"🧠 面试最常问：方法交换为啥会 crash？直接交换父类没实现的本类方法 = 影响所有子类调用都替换掉父类原始方法！");
    NSLog(@"  🏆安全铁律：先 class_addMethod 把 swizzledIMP 塞给 originalSel.成功=原来没实现 再替换 = 不会污染其他类");
    
    // 🌰 unsafe 写法（网上90%都是这个坑，直接 method_exchangeImplementations 了事
    SwizzleDemo *demo1 = [SwizzleDemo new];
    NSLog(@"\n  [Before Swizzle] 调用 originalMethod");
    [demo1 originalMethod];  // 走原本蓝色IMP
    
    // ✅ Safe Swizzle (调用安全写法
    [SwizzleDemo safeExchangeInstanceMethod:@selector(originalMethod) withMethod:@selector(swizzled_originalMethod)];
    SwizzleDemo *demo2 = [SwizzleDemo new];
    NSLog(@"\n  [After  Safe Swizzle] 调用 originalMethod → 此时已被交换");
    [demo2 originalMethod];  // 实际调用 swizzled_originalMethod 先埋点再递归调用自己(此时自己已是原方法)
    
    NSLog(@"\n🏆 大厂标准安全 Swizzle 『5 行公式代码』（面试直接背）：");
    NSLog(@"    ① Method orig = class_getInstanceMethod(cls, origSel);");
    NSLog(@"    ② Method swiz = class_getInstanceMethod(cls, swizSel);");
    NSLog(@"    ③ BOOL didAdd = class_addMethod(cls, origSel, method_getImplementation(swiz), methodTypeEncoding);");
    NSLog(@"    ④ if (didAdd)  class_replaceMethod(cls, swizSel, origM?origIMP:空兜底IMP, ...);");
    NSLog(@"         ↳ add成功=本类没origM(=继承父类或未实现) → 单独替换swizSel，绝不改父类 method list⭐️");
    NSLog(@"    ⑤ else        method_exchangeImplementations(orig, swiz);");
    NSLog(@"         ↳ add失败=本类本身就有origSel → orig在本类method list，exchange才安全⭐️");
    NSLog(@"  🧠 面试灵魂拷问三连：");
    NSLog(@"    Q1为啥不用直接exchange？→ orig为父类方法的话=污染所有子类💀");
    NSLog(@"    Q2class_addMethod成功代表啥？→ 本类method list原来没有origSel，占坑成功");
    NSLog(@"    Q3origM==nil时class_replaceMethod传啥？→ 显式空IMP兜底，别传swizM自己的IMP会递归死循环💀");
    NSLog(@"  ");
    NSLog(@"🟢 常见应用：AOP 埋点 / VC生命周期Inject / 网络请求防重复 / YA 防崩溃");
    NSLog(@"🔴 常见坑：+load 里 写 dispatch_once 保证只交换一次，不写+多次类加载来来回回换乱套.");
    NSLog(@"\n======= 【C2】Method Swizzling 演示完毕 ✅ =======\n");
}

#pragma mark C3. Associated Object 关联对象（Category 加属性原理）
- (void)demonstrateAssociatedObject {
    NSLog(@"\n\n======= 【C3】关联对象 Associated Object（Category 添加属性原理） =======\n");
    NSLog(@"🧠 面试点：Category 在 .h 写 @property 只会生成 getter/setter 声明，不会生成下划线成员变量");
    NSLog(@"   所以 .m 里必须用 objc_setAssociatedObject / objc_getAssociatedObject 手动实现存读");
    NSLog(@"   本质：底层用 AssociationsHashMap 存 (类对象指针 → ObjectAssociationMap 多个(key → value+policy))");
    NSLog(@"   存储在 SideTables 散列表中，不在对象本身内存里（这也是为啥 Category 不能直接加ivar）\n");
    
    Person *p1 = [[Person alloc] initWithName:@"张三" age:25];
    NSLog(@"  [Before设置前 p1.extTag = %@ (初始为 nil ✅", p1.extTag);
    // 写 Category 添加两个关联对象
    p1.extTag   = @(999);
    p1.extName  = @"[Associated附加名";
    NSLog(@"  [设置后] p1.extTag = %@", p1.extTag);
    NSLog(@"  [设置后] p1.extName = %@", p1.extName);
    
    Person *p2 = [[Person alloc] initWithName:@"李四" age:30];
    NSLog(@"  [另一个实例互不影响] p2.extTag = %@，p2.extName = %@", p2.extTag, p2.extName);
    
    NSLog(@"\n🧠 面试5种 policy 和 property 的对应关系（背）：");
    NSLog(@"  ┌───────────────────────────────────┬────────────────────────┐");
    NSLog(@"  │  objc_AssociationPolicy            │  @property等效       │");
    NSLog(@"  ├───────────────────────────────────┼────────────────────────┤");
    NSLog(@"  │  OBJC_ASSOCIATION_ASSIGN         │  assign             │");
    NSLog(@"  │  OBJC_ASSOCIATION_RETAIN_NONATOMIC│  strong, nonatomic  │");
    NSLog(@"  │  OBJC_ASSOCIATION_COPY_NONATOMIC  │  copy, nonatomic    │");
    NSLog(@"  │  OBJC_ASSOCIATION_RETAIN        │  strong, atomic(rarely)│");
    NSLog(@"  │  OBJC_ASSOCIATION_COPY          │  copy, atomic(rarely)│");
    NSLog(@"  └───────────────────────────────────┴────────────────────────┘");
    NSLog(@"  Key的最佳实践：static const void *kKey = &kKey;（静态变量指针地址=唯一全局不冲突）");
    NSLog(@"\n======= 【C3】关联对象演示完毕 ✅ =======\n");
}

#pragma mark - ========== 🧠【E. KVO 底层本质】 ==========

#pragma mark E1. KVO 的 isa-swizzling 本质（NSKVONotifying_ 动态子类）
- (void)demonstrateKVOIsaSwizzling {
    NSLog(@"\n\n======= 【E1】KVO 本质 = isa-swizzling 动态子类 =======\n");
    NSLog(@"🧠 面试必背：KVO 是用 Runtime isa-swizzling 实现，Apple 文档写的 6 个关键步骤：");
    NSLog(@"  ① addObserver时 Runtime动态生成 NSKVONotifying_XXX 子类继承原类");
    NSLog(@"  ② 把被观察对象的 isa 指针改指向这个新子类（所以 class）");
    NSLog(@"  ③ 子类重写 class 方法，返回原类 class(欺骗开发者以为类名还是原类");
    NSLog(@"  ④ 子类重写被观察key的 setter → willChange → 调父setter → didChange → 通知observer");
    NSLog(@"  ⑤ _isKVOA 标记返回 YES");
    NSLog(@"  ⑥ 自动手动KVO移除全部移除后isa指回原类，子类不销毁（缓存优化复用\n");
    
    Person *pNoKVO = [[Person alloc] initWithName:@"无KVO" age:20];
    Person *pWithKVO = [[Person alloc] initWithName:@"有KVO" age:22];
    
    NSLog(@"  🔵 【Before 添加 KVO 之前：");
    NSLog(@"     无KVO对象: isa指向 %s", class_getName(object_getClass(pNoKVO)));
    NSLog(@"     有KVO对象: isa指向 %s", class_getName(object_getClass(pWithKVO)));
    NSLog(@"     [pWithKVO class] = %@", [pWithKVO class]);  // 这里还没加，都为Person
    NSString *fmt = @"     object_getClass 返回实际指向的类，[obj class]被重写返回原类隐藏子类⭐️";
    NSLog(@"%@", fmt);
    
    // 添加KVO观察
    [pWithKVO addObserver:self forKeyPath:@"age" options:NSKeyValueObservingOptionNew context:nil];
    
    NSLog(@"\n  🟢 【After】添加 KVO 之后⭐️⭐️⭐️：");
    NSLog(@"     无KVO对象: isa指向 %s (还是原来的Person ✔️", class_getName(object_getClass(pNoKVO)));
    Class kvoCls = object_getClass(pWithKVO);
    NSLog(@"     有KVO对象: isa指向 %s ←⭐️⭐️⭐️ 被Runtime动态子类！", class_getName(kvoCls));
    NSLog(@"     [pWithKVO class] = %@ ← class方法被重写返回原类Person", [pWithKVO class]);
    NSLog(@"     动态子类 superclass = %@", [kvoCls superclass]);
    NSLog(@"     _isKVOA == %@", [pWithKVO valueForKey:@"_isKVO"] ?: @"(YES非公开但存在方法返回");
    
    // 触发 setter → 内部会调用 Foundation 的 _NSSetLongLongValueAndNotify 类似IMP
    pWithKVO.age = 25;  // 触发 observeValue 回调
    
    // 移除后 isa 恢复
    [pWithKVO removeObserver:self forKeyPath:@"age"];
    NSLog(@"\n  🔴 【移除KVO后】:");
    NSLog(@"     有KVO对象isa回到: %s ✅", class_getName(object_getClass(pWithKVO)));
    
    NSLog(@"\n🏆 面试延伸：手动KVO手动实现 willChangeValueForKey + didChange 才能手动触发\n");
    NSLog(@"  常见考点：直接改成员变量会不会触发 KVO？(不会，因为没走setter，必须手动加will+did)");
    NSLog(@"\n======= 【E1】KVO isa-swizzling 演示完毕 ✅ =======\n");
}

@end
