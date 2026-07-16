# MachMsgDem01 — iOS 内存 & Mach IPC 底层 Demo

## 项目概述

单 ViewController 集成 **两个底层 Demo**：

| Demo | 主题 | 核心 API |
|------|------|----------|
| **Demo 1** | autoreleasepool + 临时对象内存波动 | `task_info(MACH_TASK_BASIC_INFO)` → `resident_size` |
| **Demo 2** | mach_msg 端口阻塞与消息唤醒 | `mach_port_allocate` / `mach_port_insert_right` / `mach_msg(SEND/RCV)` |

两个 Demo 可独立运行，通过按钮触发，实时展示底层行为。

## 项目结构

```
MachMsgDem01/
├── MachMsgDem01/
│   ├── AppDelegate.swift       # App 入口
│   ├── SceneDelegate.swift     # Scene 生命周期
│   └── ViewController.swift    # 两个 Demo 全部逻辑（~435 行）
└── README.md
```

---

## Demo 1：autoreleasepool + 临时对象内存波动

### 核心实现

```swift
// 每 0.25s 读取一次 resident_size（物理内存常驻集合）
private func residentMemoryBytes() -> UInt64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(
        MemoryLayout<mach_task_basic_info>.stride / MemoryLayout<natural_t>.stride
    )

    let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
        infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &count)
        }
    }

    guard kerr == KERN_SUCCESS else { return 0 }
    return UInt64(info.resident_size)
}
```

### 内存搅动循环

```swift
memoryWorkerQueue.async {
    while isMemoryChurnRunning {
        autoreleasepool {
            var holder: [AnyObject] = []
            holder.reserveCapacity(20000)

            for i in 0..<20000 {
                let s = NSMutableString(string: "temp-\(i)-\(UUID().uuidString)")
                holder.append(s)
                holder.append(NSNumber(value: i))
                holder.append(NSDate())
                let d = NSMutableData(length: 512) ?? NSMutableData()
                holder.append(d)
            }
            _ = holder.count
        } // ← pool drain：大量临时对象被释放
        usleep(15_000)
    }
}
```

### 技术要点

| 要点 | 说明 |
|------|------|
| `task_info(MACH_TASK_BASIC_INFO)` | 通过 Mach 内核接口读取当前进程的 `resident_size`（物理内存占用），而非虚拟地址空间 |
| `autoreleasepool {}` | Swift/ObjC 互操作时 Foundation 对象走 autorelease，pool drain 时统一释放 |
| `NSMutableString` / `NSNumber` / `NSDate` / `NSMutableData` | 模拟密集临时对象创建场景 |
| `resident_size` vs `virtual_size` | `resident_size` 反映实际物理页占用，是监控内存压力的关键指标 |
| 0.25s 轮询 Timer | 加入 `RunLoop.Mode.common`，保证滚动时也能更新 UI |

**观察效果：** 开启 Demo 后，resident memory 会呈现"快速上升 → pool drain 回落"的周期波动，直观展示 autoreleasepool 的内存释放机制。

---

## Demo 2：mach_msg 端口阻塞与消息唤醒

### 核心流程

```
┌──────────────────────┐         ┌─────────────────────────┐
│   Main Thread         │         │   MachMsgReceiver Thread │
│                        │         │                          │
│ 1. mach_port_allocate  │ ──port──▶  持有 receive right      │
│    (RECEIVE right)     │         │                          │
│ 2. mach_port_insert_   │         │ 4. mach_msg(RCV, ∞)     │
│    right (SEND right)  │         │    进入内核睡眠阻塞      │
│                        │         │                          │
│ 3. mach_msg(SEND) ────▶│         │ 5. 内核唤醒线程          │
│    发送 wake 消息       │         │    处理消息 payload      │
│                        │         │                          │
│ 3'. mach_msg(SEND) ───▶│         │ 6. 收到 stop(999)       │
│     发送 stop 消息      │         │    退出循环，销毁端口    │
└──────────────────────┘         └─────────────────────────┘
```

### 端口创建

```swift
// 1) 创建 receive port
var port: mach_port_t = 0
var kr = mach_port_allocate(
    mach_task_self_,
    mach_port_right_t(MACH_PORT_RIGHT_RECEIVE),
    &port
)

// 2) 给同一个 port 插入 send right（本进程可向自己发消息）
kr = mach_port_insert_right(
    mach_task_self_, port, port,
    mach_msg_type_name_t(MACH_MSG_TYPE_MAKE_SEND)
)
```

**关键概念：**
- `MACH_PORT_RIGHT_RECEIVE` — 接收权，允许线程在该端口上阻塞等待消息
- `MACH_MSG_TYPE_MAKE_SEND` — 发送权，允许向该端口发送消息
- 同一端口可同时持有 receive right 和 send right（本 demo 中同一进程两种权限都有）

### 消息结构体

```swift
private struct SimpleMachMessage {
    var header: mach_msg_header_t = mach_msg_header_t()
    var value: UInt32 = 0           // 用户自定义 payload
}

// 手动构造 msgh_bits：Swift 中无法直接使用 C 宏 MACH_MSGH_BITS
let remoteBits = UInt32(MACH_MSG_TYPE_COPY_SEND)  // remote port 携带 COPY_SEND
let localBits: UInt32 = 0                          // local port 为空
msg.header.msgh_bits = mach_msg_bits_t(remoteBits | (localBits << 8))
msg.header.msgh_remote_port = port
msg.header.msgh_local_port = mach_port_t(MACH_PORT_NULL)
```

**msgh_bits 位布局：**

| 位域 | 含义 |
|------|------|
| bits[7:0] | remote port 的 right disposition（本 demo: `MACH_MSG_TYPE_COPY_SEND` = 19） |
| bits[15:8] | local port 的 right disposition（本 demo: 0，无 local port） |
| bits[23:16] | voucher port disposition |

### 接收线程（核心阻塞点）

```swift
Thread.current.name = "MachMsgReceiver"  // 便于在 Xcode Debug Navigator 中识别

while true {
    var msg = SimpleMachMessage()
    msg.header.msgh_size = size
    msg.header.msgh_local_port = port

    // MACH_RCV_MSG + timeout=0 → 无限等待
    // 当 port 队列为空时，该线程在内核中睡眠
    // Xcode 调用栈会停在 mach_msg2_trap / mach_msg_trap / mach_msg_overwrite_trap
    let kr = mach_msg(
        headerPtr,
        MACH_RCV_MSG,
        0,            // send_size = 0 (仅接收)
        size,         // receive size
        port,         // 监听的端口
        0,            // timeout = 0 → 无限等待
        MACH_PORT_NULL
    )

    // 检查消息 ID 决定行为
    if msg.header.msgh_id == 999 { break }  // stop 信号
    // 处理 wake 消息...
}
```

### 发送消息

```swift
// 填充 header + payload
var msg = SimpleMachMessage()
msg.value = counter
msg.header.msgh_bits = ...
msg.header.msgh_remote_port = port
msg.header.msgh_id = 100   // wake 消息 ID

// mach_msg(SEND_MSG) → 内核将消息排入 port 队列 → 唤醒阻塞的接收线程
let kr = mach_msg(headerPtr, MACH_SEND_MSG, size, 0, MACH_PORT_NULL, 0, MACH_PORT_NULL)
```

### 消息类型体系

| 消息 ID | 含义 | 发送方 | 接收后行为 |
|---------|------|--------|-----------|
| `100` (wake) | 普通唤醒消息 | Main Thread 点击 "Send Wake Once" | 打印日志，更新 UI，继续等待 |
| `999` (stop) | 停止信号 | `stopMachReceiver()` | 退出循环，`mach_port_destroy` 销毁端口 |

### 资源清理

```swift
// 停止时先发送 stop 消息确保接收线程退出
sendMachControlMessage(id: 999, value: 0)

// 接收线程退出前销毁端口
mach_port_destroy(mach_task_self_, portToDestroy)

// 状态重置
stateQueue.sync {
    machReceivePort = mach_port_t(MACH_PORT_NULL)
    isMachReceiverRunning = false
}
```

### 技术要点

| 要点 | 说明 |
|------|------|
| `mach_port_allocate` | 在内核中创建一个端口对象，返回 port name（进程内标识符） |
| `mach_port_insert_right` | 给已有端口插入额外的 right（send / send-once / dead-name 等） |
| `mach_msg(MACH_RCV_MSG, timeout=0)` | **无限阻塞接收**，类似 `select()` 但直接在内核层睡眠 |
| `mach_msg(MACH_SEND_MSG)` | 向端口发送消息，内核排入队列；如果有线程正在该端口 `RCV` 上阻塞则唤醒之 |
| `msgh_bits` 手动构造 | Swift 中无法使用 C 宏 `MACH_MSGH_BITS(remote, local)`，需按位拼装 |
| 线程命名 | `Thread.current.name = "MachMsgReceiver"` 方便在 Xcode Debug Navigator 中定位 |
| 线程安全 | `stateQueue` (串行队列) 保护 `isRunning`/`port`/`counter` 等共享状态 |
| 端口销毁 | `mach_port_destroy` 释放内核资源，接收线程应在销毁前退出 |

### 调试提示

> 开启 Demo 2 后，在 Xcode Debug Navigator 中可看到名为 **MachMsgReceiver** 的线程，其调用栈会停在 `mach_msg2_trap` / `mach_msg_trap` / `mach_msg_overwrite_trap`。点击 **Send Wake Once** 可观察线程唤醒与调用栈变化。

---

## 运行方式

```bash
cd MachMsgDem01
open MachMsgDem01.xcodeproj
# Xcode 中选择模拟器或真机 → Run
```

- Demo 1：点击 "Start Memory Churn"，观察 resident memory 波动
- Demo 2：点击 "Start Receiver" → 查看 Debug Navigator 中的 MachMsgReceiver 线程 → 点击 "Send Wake Once" 观察唤醒
- Demo 2 的 stop 通过发送 `msg_id=999` 的特殊消息实现，而非暴力终止线程

## 技术标签

`iOS` `Mach IPC` `mach_msg` `mach_port_allocate` `mach_port_insert_right` `task_info` `MACH_TASK_BASIC_INFO` `resident_size` `autoreleasepool` `Mach Kernel` `线程阻塞` `msgh_bits` `内核调度`
