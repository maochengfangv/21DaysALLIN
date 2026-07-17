# React Native 0.86 新架构实战：Fabric 原生组件开发的 4 个致命坑

> 用亲身踩坑经历，帮你少走弯路。

---

## 背景

最近在 React Native 0.86 新架构（Fabric + TurboModule）下开发一个带事件推送的 Fabric 原生组件 `NativeColoredView`，功能本身很简单：JS 侧通过 `isActive` 控制原生侧定时器，原生侧每秒通过 `onValueChange` 事件推送递增值到 JS。

从写 JS Spec → 跑 Codegen → 编译原生代码 → 运行，踩了 4 个坑，每一个都是"编译报错能看懂、但不知道为什么会这样"的类型。本文逐一复盘。

---

## 坑 1：Codegen 不认你手写的泛型事件类型

### 现象

Spec 文件里定义了一个本地泛型：

```typescript
// ❌ 错误写法
type DirectEvent<T> = { readonly nativeEvent: T };

export interface NativeProps extends ViewProps {
  onValueChange?: DirectEvent<{
    readonly value: Double;
    readonly timestamp: Double;
  }>;
}
```

执行 `pod install` 触发的 codegen 报错：

```
[Codegen] Error: Unknown prop type for "nativeEvent": "T"
```

### 原因

React Native 的 codegen 是一个**静态 AST 分析器**，不是完整的 TypeScript 编译器。它不支持泛型类型别名展开，遇到 `DirectEvent<{...}>` 时，`T` 无法被解析成具体类型。

### 解决

从 `react-native/Libraries/Types/CodegenTypes` 导入官方类型：

```typescript
// ✅ 正确写法
import type { DirectEventHandler, Double } from 'react-native/Libraries/Types/CodegenTypes';

export interface NativeProps extends ViewProps {
  onValueChange?: DirectEventHandler<{
    readonly value: Double;
    readonly timestamp: Double;
  }>;
}
```

`DirectEventHandler` 是 codegen 内置能识别的事件回调类型，它能正确展开内联的 nativeEvent 结构。

---

## 坑 2：`typeof` 在 Objective-C++ 中编译不过

### 现象

在 `.mm` 文件中用经典的 weak-strong dance：

```objc
// ❌ 报错: Expected unqualified-id
__weak typeof(self) weakSelf = self;
self.valueTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
    __strong typeof(weakSelf) self = weakSelf;
    // ...
}];
```

### 原因

`typeof` 是 GNU C 扩展，不是 C++ 标准关键字。React Native 新架构的 Fabric 组件以 **Objective-C++ (.mm)** 编译，编译器使用严格 C++ 标准，`typeof` 不被识别。

> 可以用 `__typeof__`（双下划线编译器内置），但依然不够干净。

### 解决

直接使用具体类名，避免依赖编译器扩展：

```objc
// ✅ 正确写法
__weak NativeColoredView *weakSelf = self;
self.valueTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
    NativeColoredView *strongSelf = weakSelf;
    if (!strongSelf) {
        [timer invalidate];
        return;
    }
    [strongSelf emitValueChange];
}];
```

另外用 `strongSelf` 替代 block 内 `self` 遮蔽，不会引起 `self` 的循环引用警告误报，更安全。

---

## 坑 3：`prepareForReuse` vs `prepareForRecycle`

### 现象

```objc
// ❌ No visible @interface for 'RCTViewComponentView' declares the selector 'prepareForReuse'
- (void)prepareForReuse {
    [self stopValueTimer];
    self.currentValue = 0.0;
    [super prepareForReuse];
}
```

编译报错：`RCTViewComponentView` 没有 `prepareForReuse` 方法。

### 原因

| 架构 | 基类 | 复用清理方法 |
|------|------|-------------|
| 旧架构（Paper） | `RCTView` | `prepareForReuse` |
| 新架构（Fabric） | `RCTViewComponentView` | `prepareForRecycle` |

Fabric 换了基类，方法名也换了。经验来自旧架构的惯性写法直接套到新架构就会踩坑。

### 解决

```objc
// ✅ Fabric 正确写法
- (void)prepareForRecycle {
    [self stopValueTimer];
    self.currentValue = 0.0;
    [super prepareForRecycle];
}
```

---

## 坑 4：首次挂载时 `oldProps` 解引用崩溃

### 现象

RN 页面一打开就 EXC_BAD_ACCESS 崩溃，堆栈指向：

```objc
const auto &oldViewProps = *std::static_pointer_cast<const NativeColoredViewProps>(oldProps);

// crash ↓
if (newViewProps.isActive != oldViewProps.isActive) { ... }
```

### 原因

Fabric 在**首次挂载**组件时，`updateProps:oldProps:` 传入的 `oldProps` shared_ptr **可能为 null**。这是 Fabric 与旧架构的一个重要语义差异：

- 旧架构：首次 mount 时也有一个默认 props 对象
- Fabric：首次 mount 时 oldProps 为空 shared_ptr，表示"之前没有 props"

代码中对 `oldProps` **直接解引用**（`*static_pointer_cast<...>(oldProps)`），碰到 null shared_ptr 导致 EXC_BAD_ACCESS。

### 解决

不要对 `oldProps` 直接解引用，改用 shared_ptr 的值语义 + 防御判断：

```objc
// ✅ 安全写法
- (void)updateProps:(const Props::Shared &)props
           oldProps:(const Props::Shared &)oldProps {
  const auto &newViewProps = *std::static_pointer_cast<const NativeColoredViewProps>(props);
  const auto oldViewProps = std::static_pointer_cast<const NativeColoredViewProps>(oldProps);

  [super updateProps:props oldProps:oldProps];

  // ... color, cornerRadius 处理 ...

  // 防御：oldProps 在首次挂载时可能为 null
  BOOL wasActive = oldViewProps ? oldViewProps->isActive : false;
  if (newViewProps.isActive != wasActive) {
    if (newViewProps.isActive) {
      [self startValueTimer];
    } else {
      [self stopValueTimer];
    }
  }
}
```

关键变化：`oldViewProps` 从**引用**改为**值**（shared_ptr），通过 `shared_ptr` 的 bool 转换操作符判断是否为空，再安全访问。

---

## 总结

| # | 现象 | 根因 | 解法 |
|---|------|------|------|
| 1 | codegen 报 `Unknown prop type` | 泛型别名不被 codegen 解析 | 用官方 `DirectEventHandler<T>` |
| 2 | 编译报 `Expected unqualified-id` | Objective-C++ 不认 `typeof` | 用具体类名，不用扩展语法 |
| 3 | `No visible @interface` | 新旧架构 API 名称不同 | Fabric 用 `prepareForRecycle` |
| 4 | 首次打开页面 EXC_BAD_ACCESS | Fabric 首次挂载 oldProps 为 null | shared_ptr 解引用前做 null 检查 |

这四个坑的共同特征：**都源于新架构与旧架构/常规写法的细微差异**。React Native 新架构带来了更好的性能，但 API 契约和编译约束也更加严格，写 Fabric 组件时不能照搬旧架构的经验。

---

*如果你也在 React Native 新架构中踩过坑，欢迎评论区补充交流。*
