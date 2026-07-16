# PerfTuningSimDemo2 — iOS 性能劣化模拟 & Instruments 排查训练

## 项目概述

一个用于 **性能排查方法论训练** 的 iOS Demo，同时运行 **4 种性能劣化场景**（内存抖动、视图抖动、定时器风暴、CPU 高位），每种场景均有 **Bad（注入问题）vs Optimized（修复对照）** 双模式。配合 Instruments（Leaks/Allocations/Time Profiler）使用，形成"复现 → 定位 → 取证 → 修复 → 验证"的完整排查闭环。

## 项目结构

```
PerfTuningSimDemo2/
├── PerfTuningSimDemo2/
│   ├── ViewController.swift    # 全部逻辑（~686 行）：4 种场景 + 实时指标采集
│   ├── readme.md               # 泄漏排查方法论随记（Instruments Leaks 实战）
│   ├── AppDelegate.swift
│   └── SceneDelegate.swift
└── PerfTuningSimDemo2.xcodeproj
```

---

## 四种性能劣化场景

### 场景 1：内存抖动（Memory Churn）+ 可控泄漏

| 维度 | Bad 模式 | Optimized 模式 |
|------|----------|----------------|
| 每轮分配对象数 | 14,000 | 6,000 |
| 数据类型 | `NSMutableString` + `NSNumber` + `NSDate` + `NSMutableData(4096B)` | 同上但 `NSMutableData(2048B)` |
| autoreleasepool | **无** — autorelease 对象生命周期依赖 RunLoop drain | **有** — 每轮包裹 `autoreleasepool {}`，缩短生命周期 |
| 节流 | 无（持续高频分配） | `usleep(15ms)` |
| **可控泄漏** | ✅ 每次 `maybeLeakMemoryOnce()` — `UnsafeMutableRawPointer.allocate(256KB)` 不释放 | ❌ 不泄漏 |
| 泄漏预算 | `24MB` — 达到上限停止泄漏 | — |
| Instruments 验证 | Leaks 稳定命中 → backtrace 指向 `maybeLeakMemoryOnce()` | Leaks 无事件 |

```swift
// 泄漏代码：绕过 ARC，手动分配原生内存不释放
let p = UnsafeMutableRawPointer.allocate(byteCount: 256 * 1024, alignment: 16)
p.initializeMemory(as: UInt8.self, repeating: 0xA5, count: chunk)
// 没有 deallocate() — Instruments Leaks 可识别并定位
```

### 场景 2：视图抖动（View Churn）

| 维度 | Bad 模式 | Optimized 模式 |
|------|----------|----------------|
| 驱动 | `CADisplayLink` (60fps, `.common` mode) | 同上 |
| 每帧创建 | **新 `UIView()` × 60** — 分配 + 插入层级 + 随机 frame | 从 **预创建 pool (400 个)** 中循环复用 |
| 布局 | `setNeedsLayout()` + `layoutIfNeeded()` 每帧 | 同上但只改 frame，复用 view |
| 上限 | > 1200 个时批量移除 300 个 | 无额外清理（fixed pool） |
| 渲染压力 | 高频分配 + 层级增删 + 合成 | 仅移动复用，分配隔离在预创建阶段 |

```swift
// Optimized: 预创建池 → 复用
let pool = (0..<400).map { _ in UIView() }
let v = pool[index % pool.count]
if v.superview == nil { canvasView.addSubview(v) }
v.frame = randomRect()  // 只改 frame

// Bad: 每帧 new + add + 超标清理
let v = UIView()
canvasView.addSubview(v)
```

### 场景 3：定时器风暴（Timer Storm）

| 维度 | Bad 模式 | Optimized 模式 |
|------|----------|----------------|
| Timer 数量 | **16 个**（初始） | **1 个** |
| 间隔 | 0.02s (50Hz) | 0.05s (20Hz) |
| 单位工作量 | 5,000 次整型运算 | 2,000 次 |
| Spawner | ✅ 每秒额外创建 **6 个** Timer（上限 40） | ❌ |
| 主线程影响 | 多 Timer 并发回调 + 增殖 = 回调拥塞 | 单 Timer = 可预测负载 |
| RunLoop Mode | `.common`（保证持续触发） | `.common` |

### 场景 4：CPU 高位燃烧（CPU Burn）

| 维度 | Bad 模式 | Optimized 模式 |
|------|----------|----------------|
| 线程 | `.userInitiated` 后台队列 | 同上 |
| 每轮迭代 | **200,000** 次 Xorshift 伪随机 | **40,000** 次 |
| 节流 | 无 | `usleep(10ms)` |
| CPU 表现 | 接近 100%（单核） | 可控在 10-30% |
| 可中断性 | 迭代密集，中断响应慢 | sleep 提供中断窗口 |

---

## 实时指标采集

### Resident Memory

```swift
// task_info(MACH_TASK_BASIC_INFO) → mach_task_basic_info.resident_size
// 物理页实际占用，非虚拟地址
private func residentMemoryBytes() -> UInt64 { ... }
```

### Process CPU Usage

```swift
// 枚举所有线程: task_threads() → thread_info(THREAD_BASIC_INFO)
// 累加 cpu_usage / TH_USAGE_SCALE * 100 → 总 CPU%
// 跳过 TH_FLAGS_IDLE 线程
// 释放: mach_port_deallocate 每个 thread port + vm_deallocate 数组
private func processCPUUsagePercent() -> Double { ... }
```

| 要点 | 说明 |
|------|------|
| `task_threads` | 返回 task 拥有的所有线程的 `thread_t` 数组 |
| `thread_info(THREAD_BASIC_INFO)` | 读取单个线程的 `cpu_usage`（定点数） |
| `TH_FLAGS_IDLE` | 空闲线程标记，跳过不累计 |
| `defer` 释放 | `mach_port_deallocate` 每个线程 + `vm_deallocate` 数组 |
| 刷新间隔 | Timer 0.3s, `.common` mode 保证滚动时继续更新 |

---

## 排查方法论

详见同目录 [readme.md](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/PerfTuningSimDemo2/PerfTuningSimDemo2/readme.md)，核心流程：

```
1. 复现 → Bad 模式 + Start All + Instruments 录制
2. 定位 → Leaks/Time Profiler backtrace 指向具体代码行
3. 解释 → UnsafeMutableRawPointer 绕过 ARC → 必须显式 deallocate
4. 修复思路：
   (a) 对称释放：分配后 deallocate()
   (b) 自动封装：对象 in deinit 释放指针
   (c) 不用手动内存：改回 Data/Foundation 容器
5. 验证 → Optimized 模式 + 同样步骤 + Leaks 不再出现
```

**三个关键原则：**
- **可重复**：Bad/Optimized 明确开关，同一套步骤得到同一个结论
- **可取证**：Instruments 直接指向代码行，不是"感觉"
- **可对照**：优化前后同一个指标有明确的数值变化

---

## 泄漏预算设计

```swift
// 避免无限泄漏导致 OOM kill
var leakBudgetBytes: Int = 24 * 1024 * 1024   // 24MB 上限
var leakedBytes: Int = 0

private func maybeLeakMemoryOnce() {
    guard leaked < budget else { return }  // 达到预算停止
    let p = UnsafeMutableRawPointer.allocate(...)
    leakedBytes += chunk
}
```

- 每次泄漏 256KB，最多 96 次（24MB / 256KB）
- 不会真正 OOM，但足够让 Leaks 产生明显堆叠

---

## Bad → Optimized 对比清单

| 场景 | Bad 问题 | Optimized 方案 | 验证工具 |
|------|----------|---------------|----------|
| 内存抖动 | 无 autoreleasepool + 无节流 + 泄漏 | `autoreleasepool` + `usleep` + 零泄漏 | Leaks, Allocations |
| 视图抖动 | 每帧 new UIView → 分配压力 | 预创建 pool + 循环复用 | Time Profiler (Core Animation) |
| 定时器风暴 | 16+ Timer + Spawner 增殖 | 1 Timer + 低负载 | Time Profiler (主线程) |
| CPU 高位 | 200k 迭代 + 无中断 | 40k + sleep 10ms | Time Profiler (CPU Usage) |

---

## 运行方式

```bash
cd PerfTuningSimDemo2
open PerfTuningSimDemo2.xcodeproj
# Xcode 菜单 → Product → Profile（⌘I）
# 选择 Instruments: Leaks / Allocations / Time Profiler
```

1. **Leaks**：选择 `Leaks` 模板 → Bad 模式 → Start Memory Churn → 等待红点
2. **Allocations**：对比 Bad/Optimized 的 All Heap & Anonymous VM 增长曲线
3. **Time Profiler**：Start All → 观察 `allocateBurst` / `cpuBurnStep` / `timerStormWork` 权重变化

## 技术标签

`iOS` `性能优化` `Instruments` `Leaks` `Allocations` `Time Profiler` `UnsafeMutableRawPointer` `内存泄漏` `task_info` `thread_info` `CADisplayLink` `Timer Storm` `CPU Burn` `autoreleasepool` `可控泄漏` `性能排查闭环`
