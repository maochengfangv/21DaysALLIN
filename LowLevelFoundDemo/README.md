# LowLevelFoundDemo — iOS 底层原理综合 Demo

## 项目概述

一工程集成 **7 个 iOS 底层原理可运行 Demo**，覆盖 Mach-O 段表解析、ObjC Runtime 消息转发三阶段、RunLoop Mode 切换、dyld 工作量快照、代码签名/VM 内存保护/越狱检测、灰度发布/金丝雀回滚等模块。每个 Demo 均提供按钮触发 → 日志输出的交互方式，可直接用于面试讲解或技术评审演示。

## 项目结构

```
LowLevelFoundDemo/
├── LowLevelFoundDemo/
│   ├── AppDelegate.swift          # App 入口
│   ├── SceneDelegate.swift        # Scene 生命周期
│   ├── ViewController.swift       # 7 个 Demo 的 UI 与 Swift 侧逻辑（核心，~1220 行）
│   └── LFForwardingEntry.m        # ObjC 侧：消息转发三阶段 + +load 计时埋点
├── CI/
│   ├── ci.py                      # Python CI 脚本（xcodebuild archive/export + 资源优化）
│   └── ci.sh                      # Shell 包装脚本
└── README.md
```

## 架构流程

```
ViewController (Swift, ~1220 行)
  ├── Demo 1: Mach-O 段表解析
  │     mainMachO64() → 遍历 load_command → LC_SEGMENT_64 → section_64
  │
  ├── Demo 2: ObjC 消息转发（通过 LFForwardingEntry.m）
  │     NSClassFromString("LFForwardingEntry") → perform("runDemo")
  │       ├── resolveInstanceMethod: (class_addMethod 动态注入)
  │       ├── forwardingTargetForSelector: (快速转发到备用对象)
  │       └── forwardInvocation: (NSInvocation 完整转发)
  │
  ├── Demo 3: RunLoop Mode 切换
  │     Timer(0.25s, .default) vs Timer(0.25s, .common)
  │     拖动 trackingScrollView → UITrackingRunLoopMode
  │
  ├── Demo 4: 底层面试题库（8 题）
  │
  ├── Demo 5: dyld 工作量 / dlopen Benchmark
  │     _dyld_image_count / _dyld_get_image_name / _dyld_get_image_vmaddr_slide
  │     _dyld_register_func_for_add_image (回调收集)
  │     mach_absolute_time 精确计时 +load 顺序
  │     dlopen RTLD_LAZY vs RTLD_NOW 200轮对比
  │
  ├── Demo 6: 安全与签名
  │     LC_CODE_SIGNATURE / LC_ENCRYPTION_INFO_64 解析
  │     段 initprot/maxprot vs vm_region_64() 运行时对比
  │     越狱检测：路径扫描 + 沙盒写入 + dyld 镜像 + 环境变量 + dlsym Hook
  │
  └── Demo 7: 灰度发布 / 金丝雀回滚（本地模拟）
        Stable vs Canary 选择 + Fault 注入 → 自动回滚到 Stable
```

---

## Demo 1：Mach-O 段表解析

```swift
// mainMachO64() 定位主可执行文件
guard let main = mainMachO64() else { return }

// 越过 mach_header_64，遍历 load_command 链
var cursor = UnsafeRawPointer(main.header)
    .advanced(by: MemoryLayout<mach_header_64>.size)

for _ in 0..<Int(main.header.pointee.ncmds) {
    let cmd = cursor.assumingMemoryBound(to: load_command.self).pointee

    if cmd.cmd == UInt32(LC_SEGMENT_64) {
        let seg = cursor.assumingMemoryBound(to: segment_command_64.self).pointee
        // 段名、vmaddr、vmsize、initprot、maxprot
        // 继续遍历 section_64 数组 (seg.nsects 个)
    }
    cursor = cursor.advanced(by: Int(cmd.cmdsize))
}
```

| 输出项 | 说明 |
|--------|------|
| dyld image count | `_dyld_image_count()` |
| slide（ASLR 偏移） | `_dyld_get_image_vmaddr_slide(index)` |
| 段表（`__TEXT`/`__DATA`/`__LINKEDIT` 等） | 段名、vmaddr、vmsize、nsects、initprot、maxprot |
| Section 详情 | `__TEXT/__text`、`__DATA/__data` 等，含 addr + size |

**展示的 Mach-O 知识点：**
- `mach_header_64` 结构 → `ncmds`/`sizeofcmds` → load commands 线性排列
- `LC_SEGMENT_64` → `segment_command_64` → `section_64` 数组
- `_dyld_get_image_vmaddr_slide` → ASLR slide 含义
- 面试高频：`__TEXT`（代码，r-x）、`__DATA`（全局变量，r-w）、`__LINKEDIT`（符号/字符串表，r--）

---

## Demo 2：ObjC Runtime 消息转发三阶段

实现在 [LFForwardingEntry.m](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/LowLevelFoundDemo/LowLevelFoundDemo/LFForwardingEntry.m) 中，通过 `objc_msgSend` 显式发送消息触发完整转发链路：

```
objc_msgSend(receiver, "dynamicGreeting")
  → 不存在 → 第一阶段: resolveInstanceMethod:
       → class_addMethod 动态注入方法体 → 成功返回

objc_msgSend(receiver, "fastGreeting")
  → 不存在 → 第一阶段未处理 → 第二阶段: forwardingTargetForSelector:
       → 返回 LFFastForwardTarget 实例（快速转发，无 NSInvocation 开销）

objc_msgSend(receiver, "fullGreeting")
  → 不存在 → 前两阶段未处理 → 第三阶段:
       → methodSignatureForSelector: 合成签名
       → forwardInvocation: 调用 LFFullForwardProxy
```

**关键代码：**

```objc
// 第一阶段
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if (sel == NSSelectorFromString(@"dynamicGreeting")) {
        return class_addMethod(self, sel, (IMP)LFDynamicGreeting, "@@:");
    }
    return [super resolveInstanceMethod:sel];
}

// 第二阶段
- (id)forwardingTargetForSelector:(SEL)sel {
    if (sel == NSSelectorFromString(@"fastGreeting")) {
        return [LFFastForwardTarget new];
    }
    return [super forwardingTargetForSelector:sel];
}

// 第三阶段
- (void)forwardInvocation:(NSInvocation *)invocation {
    if (invocation.selector == NSSelectorFromString(@"fullGreeting")) {
        [invocation invokeWithTarget:[LFFullForwardProxy new]];
        return;
    }
    [super forwardInvocation:invocation];
}
```

**三阶段对比：**

| 阶段 | 方法 | 成本 | 适用场景 |
|------|------|------|----------|
| 1 | `resolveInstanceMethod:` | 低（类级缓存） | 动态添加方法实现（`@dynamic`、Core Data） |
| 2 | `forwardingTargetForSelector:` | 较低 | 将消息直接转发给另一个对象（代理/组合） |
| 3 | `forwardInvocation:` | 高（需构建 NSInvocation） | 需要修改 selector、参数或同时转发给多个对象 |

---

## Demo 3：RunLoop Mode 切换

并排运行两个 0.25s 间隔的 Timer：

```swift
// 仅 DefaultMode 触发，Tracking 时暂停
let defaultTimer = Timer(timeInterval: 0.25, repeats: true) { ... }
RunLoop.main.add(defaultTimer, forMode: .default)

// CommonModes 包含 Default + Tracking，全程触发
let commonTimer = Timer(timeInterval: 0.25, repeats: true) { ... }
RunLoop.main.add(commonTimer, forMode: .common)
```

拖动横向 ScrollView 时：
- RunLoop 进入 `UITrackingRunLoopMode`
- `default` Timer 暂停，tick 停止增长
- `common` Timer 继续触发，tick 正常增长
- `scrollViewWillBeginDragging` / `scrollViewDidEndDecelerating` 记录日志

**展示知识点：**
- `RunLoop.Mode.default` 仅限默认模式
- `RunLoop.Mode.common` 含 `default + tracking + others`
- `UITrackingRunLoopMode` 在用户交互时接管
- 面试高频：为什么 `NSTimer` 在 `tableView` 滚动时暂停？如何解决？

---

## Demo 4：底层面试实操题库

8 个话题，每个话题对应工程内可运行的 Demo：

| # | 话题 | 对应 Demo |
|---|------|-----------|
| 1 | Mach-O 基础（mach_header_64, load_command, segment_command_64, section_64） | Demo 1 |
| 2 | dyld 与镜像装载（image_count, get_image_name, slide） | Demo 5 |
| 3 | ObjC 消息转发三阶段 | Demo 2 |
| 4 | RunLoop Mode（default, UITracking, common） | Demo 3 |
| 5 | NSTimer 与主线程卡顿 | Demo 3 |
| 6 | 底层实操建议（复现→观察→追源码） | — |
| 7 | 启动/首帧性能（dyld workload, lazy vs non-lazy） | Demo 5 |
| 8 | 安全与签名（LC_CODE_SIGNATURE, 段权限, __DATA_CONST） | Demo 6 |

---

## Demo 5：dyld 工作量快照 + dlopen Benchmark

### 5a. dyld 工作量快照

```
dyld image count: xxx
iterate images (sum ncmds/sizeofcmds): x.xxx ms
total ncmds: xxx, total sizeofcmds: xxx bytes

main image: /path/to/LowLevelFoundDemo.app/LowLevelFoundDemo
slide: 0x...
main ncmds: xx, sizeofcmds: xx

loaded images (top 24):
  [00] slide=0x... /path/to/LowLevelFoundDemo
  ...

+load execution (instrumented, app-side):
  0.127 ms +load LFLoadDemoA main=YES
  0.129 ms +load LFLoadDemoB main=YES
  0.130 ms +load LFLoadDemoC main=YES

dyld add_image events (since observer registration):
  ...
```

### 5b. +load 执行顺序与线程检测

[LFForwardingEntry.m](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/LowLevelFoundDemo/LowLevelFoundDemo/LFForwardingEntry.m) 中 `LFLoadDemoA/B/C` 三个类各实现 `+load`，使用 `mach_absolute_time` 记录高精度时间戳和主线程标志：

```objc
@implementation LFLoadDemoA
+ (void)load {
    LFLoadLog([NSString stringWithFormat:@"%.3f ms +load %@ main=%@",
        LFLoadNowMS(), NSStringFromClass(self),
        [NSThread isMainThread] ? @"YES" : @"NO"]);
}
@end
```

### 5c. dyld add_image 回调收集

```swift
_dyld_register_func_for_add_image { header, slide in
    // 通过 mach_absolute_time 记录每个 image 加载的时间点
    // 通过 dyldEventQueue 线程安全收集，上限 80 条
}
```

### 5d. dlopen Benchmark（Lazy vs Now）

```swift
// 对系统 dylib（如 /usr/lib/libobjc.A.dylib）进行 200 轮 dlopen/dlclose
let lazy = measure(flag: RTLD_LAZY, rounds: 200)
let now  = measure(flag: RTLD_NOW,  rounds: 200)

// 输出 (ok/fail/count) + 耗时 (via clock_gettime_nsec_np)
```

**展示知识点：**
- `RTLD_NOW` 倾向 eager bind（启动时解析全部符号）
- `RTLD_LAZY` 延迟到首次使用（首次调用可能卡顿）
- 系统库已在 dyld shared cache 中，差异可能很小，但概念与启动优化直接相关

---

## Demo 6：安全与签名 + 越狱检测

### 6a. 代码签名 / VM 内存保护

```
LC_CODE_SIGNATURE: dataoff=0x... datasize=0x...
LC_ENCRYPTION_INFO_64: cryptoff=0x... cryptsize=0x... cryptid=0

segment init/max prot (from Mach-O):
  __TEXT: init=r-x max=r-x
  __DATA: init=r-w max=r-w
  __DATA_CONST: init=r-w max=r-w
  __LINKEDIT: init=r-- max=r--

runtime VM protections (from mach_vm_region):
  __TEXT: cur=r-x max=r-x regionSize=0x...
  __DATA: cur=r-w max=r-w regionSize=0x...
  __LINKEDIT: cur=r-- max=r-- regionSize=0x...
```

**关键实现：**

```swift
// 从 load_command 链中提取 LC_CODE_SIGNATURE / LC_ENCRYPTION_INFO_64
if cmd.cmd == UInt32(LC_CODE_SIGNATURE) {
    let cs = cursor.assumingMemoryBound(to: linkedit_data_command.self).pointee
    codeSig = (cs.dataoff, cs.datasize)
}

// 通过 vm_region_64() 查询运行时的实际 VM 保护
let kr = vm_region_64(mach_task_self_, &addr, &size,
    VM_REGION_BASIC_INFO_64, intPtr, &count, &objectName)
```

**对比意义：** Segment 的 `initprot` 定义在 Mach-O 文件中，`vm_region_64` 查询的 `cur` 是内核实际应用的权限。正常 App 中两者一致；越狱环境下可能不一致。

### 6b. 越狱检测（5 维评分体系）

| 检测维度 | 方法 | 权重 | Real 模式 | Demo 模式 |
|----------|------|------|-----------|-----------|
| 路径扫描 | `FileManager.fileExists` 检查 8 个可疑路径 | 命中数 | 真实检测 | 模拟 Cydia/Substrate/var/jb |
| 沙盒写入 | 尝试写 `/private/` 和 `/var/tmp/` | 0 或 2 | 真实写入测试 | 模拟成功 |
| dyld 镜像 | 遍历 `_dyld_get_image_name` 匹配 9 个关键词 | 命中数 | 真实遍历 | 模拟 FridaGadget |
| 环境变量 | `getenv("DYLD_INSERT_LIBRARIES")` 等 3 个 key | 命中数 | 真实检查 | 模拟注入 |
| dlsym Hook | `dlsym(RTLD_NEXT)` 查找 8 个 Hook 函数符号 | 命中数 | 真实扫描 | 模拟 MSHook/rebind |

```swift
// dlsym Hook 检测：从当前进程查找已知 Hook 框架的导出符号
let ptr = dlsym(handle, "MSHookFunction")
if let ptr {
    // 通过 dladdr 定位符号所属 image
    dladdr(ptr, &info)
    hits.append("MSHookFunction=0x... in /usr/lib/libsubstrate.dylib")
}
```

**评分机制：** `score = sum(每个维度的 weight)`，score=0 表示未检测到越狱特征，分数越高越可疑。Real/Demo 模式切换通过 `UISegmentedControl` 控制。

---

## Demo 7：灰度发布 / 金丝雀回滚（本地模拟）

```
选择 Stable/Canary → 选择 OK/Fault → Apply
  if Canary + Fault:
    effective = "Stable" (自动回滚)
    reason = "rollback(hardcoded)"
  else:
    effective = selected
```

```swift
private func renderRolloutStatus(persist: Bool) {
    if selectedVariant == "Canary" {
        do {
            payload = try renderCanaryFeature(simulateFault: selectedFault)
        } catch {
            effective = "Stable"
            reason = "rollback(hardcoded)"  // 金丝雀版本异常 → 自动回滚
            payload = renderStableFeature()
        }
    } else {
        payload = renderStableFeature()
    }
}
```

- **持久化**：通过 `UserDefaults` 存储 variant/fault 状态
- **Reset**：清除 UserDefaults 恢复默认
- **Stable 版本**：普通 JSON `{"version":"stable", "message":"稳定版本逻辑（老分支）"}`
- **Canary 版本**：扩展 JSON `{"version":"canary", "extra":{"new_ui":true, "algo":"v2"}}`
- **Fault 注入**：`renderCanaryFeature` 抛 `RolloutError.simulatedReleaseFault` → 自动回滚

---

## CI 脚本

### ci.py（Python 3）

| 功能 | 参数 |
|------|------|
| xcodebuild archive | `--archive --scheme xxx --workspace xxx.xcworkspace` |
| IPA 导出 | `--export-options ExportOptions.plist` |
| 资源优化 | `--optimize-assets --assets-dir path` (依赖 pngquant/jpegoptim) |
| 自动版本标记 | `--rename` 从 Info.plist 读取版本号 + 时间戳重命名产物 |
| ZIP 打包 | `--zip` |

### ci.sh（Shell 包装）

```bash
# 有 ExportOptions → archive + export IPA
bash ci/ci_build.sh <xcodeproj> <scheme> Release

# 无 ExportOptions → build + zip
EXPORT_OPTIONS_PLIST=ExportOptions.plist bash ci/ci_build.sh ...
```

---

## 运行方式

```bash
cd LowLevelFoundDemo
open LowLevelFoundDemo.xcodeproj
# Xcode 中选择模拟器或真机 → Run
```

每个 Demo 区域均有独立按钮，点击后输出对应日志。RunLoop Demo 需要拖动横向滚动区域观察 mode 切换效果。

## 技术标签

`iOS` `Mach-O` `load_command` `LC_SEGMENT_64` `Objective-C Runtime` `消息转发` `resolveInstanceMethod` `forwardingTargetForSelector` `forwardInvocation` `RunLoop` `UITrackingRunLoopMode` `dyld` `mach_absolute_time` `dlopen` `RTLD_LAZY` `RTLD_NOW` `LC_CODE_SIGNATURE` `vm_region_64` `越狱检测` `dlsym` `金丝雀发布` `ASLR` `CI/CD`
