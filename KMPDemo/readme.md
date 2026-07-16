# KMP Demo — Kotlin Multiplatform 跨平台实践

## 项目概述

使用 Kotlin Multiplatform (KMP) 搭建 **expect/actual 共享模块**，在 Android 和 iOS 双端复用业务逻辑。重点记录了 iOS 端集成过程中遇到的 **5 大典型陷阱** 及解决方案，并输出 **5 步配置 Checklist**，可直接作为团队 KMP 接入文档。

## 项目结构

```
KMPDemo/
├── shared/                          # KMP 共享模块
│   ├── src/
│   │   ├── commonMain/              # 跨平台公共代码
│   │   │   └── kotlin/.../
│   │   │       └── Greeting.kt      # expect 声明 + 共享业务逻辑
│   │   ├── androidMain/             # Android actual 实现
│   │   │   └── kotlin/.../
│   │   │       └── Platform.android.kt
│   │   └── iosMain/                 # iOS actual 实现
│   │       └── kotlin/.../
│   │           └── Platform.ios.kt
│   └── build.gradle.kts             # KMP Gradle 配置（多目标 + Framework 导出）
├── androidApp/                      # Android 宿主 App
├── iosApp/                          # iOS 宿主 App（SwiftUI + Xcode 工程）
├── gradle/
│   └── libs.versions.toml           # 版本目录（Kotlin 2.0.21, AGP 8.5.2）
├── settings.gradle.kts
└── readme.md
```

## 架构概览

```
┌──────────────────────────────────────────────┐
│               commonMain (共享)                │
│  expect fun getPlatformName(): String        │
│  class Greeting { greet() }                   │
│  ↓ 编译为 ↓                                    │
├──────────────────┬───────────────────────────┤
│   androidMain    │       iosMain             │
│  actual fun      │  actual fun               │
│  → "Android 34"  │  → UIDevice.current       │
│  → .jar/.aar     │  → shared.framework       │
└──────────────────┴───────────────────────────┘
           ↓                     ↓
    androidApp/              iosApp/
  MainActivity.kt         ContentView.swift
  (Kotlin/JVM)            (SwiftUI + import shared)
```

---

## 技术要点

### 一、expect/actual 模式

**commonMain 声明接口：**

```kotlin
// shared/src/commonMain/.../Greeting.kt
expect fun getPlatformName(): String  // 声明：每个平台必须提供实现

class Greeting {
    private val platform: String = getPlatformName()

    fun greet(): String = "Hello from KMP on $platform"
}
```

**Android actual 实现：**

```kotlin
// shared/src/androidMain/.../Platform.android.kt
actual fun getPlatformName(): String = "Android ${android.os.Build.VERSION.SDK_INT}"
```

**iOS actual 实现：**

```kotlin
// shared/src/iosMain/.../Platform.ios.kt
import platform.UIKit.UIDevice

actual fun getPlatformName(): String =
    "${UIDevice.currentDevice.systemName} ${UIDevice.currentDevice.systemVersion}"
```

**iOS 侧 SwiftUI 调用：**

```swift
import shared  // KMP 导出的 Framework

struct ContentView: View {
    var body: some View {
        Text(Greeting().greet())  // "Hello from KMP on iOS 18.2"
    }
}
```

**关键设计原则：**
- `expect` 声明在 `commonMain`，定义跨平台接口契约
- `actual` 实现在各平台 SourceSet，各自调用平台原生 API
- 共享业务逻辑（`Greeting` 类）完全写在 `commonMain`，不依赖平台
- `platform.UIKit.UIDevice` 是 Kotlin/Native 自动映射的 iOS SDK API

### 二、Gradle 多目标配置

```kotlin
// shared/build.gradle.kts
kotlin {
    androidTarget {
        compilations.all {
            compileTaskProvider.configure {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
                }
            }
        }
    }

    listOf(
        iosX64(),                // Intel Mac 模拟器
        iosArm64(),              // 真机
        iosSimulatorArm64()      // Apple Silicon 模拟器
    ).forEach {
        it.binaries.framework {
            baseName = "shared"  // 导出 Framework 名称
            isStatic = true      // 静态库（默认）
        }
    }
}
```

| 目标 | 用途 | Gradle Task |
|------|------|-------------|
| `androidTarget` | Android JVM | `:shared:compileDebugKotlinAndroid` |
| `iosX64` | Intel Mac 模拟器 | `:shared:linkDebugFrameworkIosX64` |
| `iosSimulatorArm64` | Apple Silicon 模拟器 | `:shared:linkDebugFrameworkIosSimulatorArm64` |
| `iosArm64` | 真机 | `:shared:linkDebugFrameworkIosArm64` |

### 三、版本依赖

```toml
# gradle/libs.versions.toml
[versions]
agp = "8.5.2"       # Android Gradle Plugin
kotlin = "2.0.21"   # Kotlin Multiplatform

[plugins]
kotlinMultiplatform = { id = "org.jetbrains.kotlin.multiplatform", version.ref = "kotlin" }
kotlinAndroid = { id = "org.jetbrains.kotlin.android", version.ref = "kotlin" }
androidApplication = { id = "com.android.application", version.ref = "agp" }
androidLibrary = { id = "com.android.library", version.ref = "agp" }
```

---

## iOS 集成踩坑记录

### 坑 1：System.currentTimeMillis() 在 iOS 编译失败

**现象：**

```
Unresolved reference 'System'
```

**原因：**

`System.currentTimeMillis()` 是 JVM 专属 API，Kotlin/Native（iOS）不提供。

**解决：**

从 `commonMain` 中移除所有 JVM 专属 API。如需跨平台获取时间戳，使用 `expect/actual` 或 `kotlinx-datetime` 库。

---

### 坑 2：iosApp 目录无法直接拖入 Xcode 打开

**现象：**

```
Could not open file. (/path/to/KMPDemo/iosApp)
```

**原因：**

`iosApp/` 目录只有 Swift 源文件，缺少 `.xcodeproj` 工程文件。

**解决：**

在 Xcode 中 File → New → Project → iOS → App，将工程创建到 `iosApp/` 目录下。

---

### 坑 3：shared.framework 未正确配置导致 undefined symbol

**现象：**

```
Undefined symbol: _OBJC_CLASS_$_SharedGreeting
Linker command failed with exit code 1
```

**原因（多项）：**

1. **Static framework 不需要 Embed Frameworks**
   - KMP 默认 `isStatic = true`，静态框架在链接时已打入二进制，不应放入 Embed Frameworks phase，否则 Xcode 可能因 codesign 等问题导致链接路径异常。

2. **OTHER_LDFLAGS 缺少 $inherited 和显式 -framework**
   - 如果 `OTHER_LDFLAGS` 只写了 `"-ObjC"` 且没有 `$(inherited)`，会覆盖 Xcode 默认传递给 linker 的参数，导致 linker 不知道去搜索 framework。
   - 正确写法：
     ```
     OTHER_LDFLAGS = (
         "$(inherited)",
         "-ObjC",
         "-framework",
         shared,
     );
     ```

3. **Framework Search Paths 路径不对**
   - 必须指向编译产物目录，例如 `$(SRCROOT)/../shared/build/bin/iosX64/debugFramework`

---

### 坑 4：架构不匹配（arm64 vs x86_64）

**现象：**

```
Undefined symbols for architecture x86_64
```

**原因：**

Intel Mac 的模拟器运行在 **x86_64** 架构，而 KMP 默认编译的是 `iosSimulatorArm64`（arm64）。两者链接时不兼容。

**解决：**

| Mac 类型 | Framework Search Paths | Run Script Gradle Task |
|----------|----------------------|------------------------|
| Intel Mac | `$(SRCROOT)/../shared/build/bin/iosX64/debugFramework` | `:shared:linkDebugFrameworkIosX64` |
| Apple Silicon | `$(SRCROOT)/../shared/build/bin/iosSimulatorArm64/debugFramework` | `:shared:linkDebugFrameworkIosSimulatorArm64` |

Run Script 中对应修改：
```bash
# Intel Mac
./gradlew :shared:linkDebugFrameworkIosX64

# Apple Silicon
./gradlew :shared:linkDebugFrameworkIosSimulatorArm64
```

---

### 坑 5：Xcode 16 兼容性警告

**现象：**

```
The selected Xcode version (16.2) is higher than the maximum known to the Kotlin Gradle Plugin
```

**解决：**

在 `gradle.properties` 中添加：
```properties
kotlin.apple.xcodeCompatibility.nowarn=true
```

---

## 正确配置 Checklist

在 Xcode 中对 iosApp target 完成以下配置：

| 步骤 | 配置项 | 值 |
|------|--------|-----|
| 1 | Build Phases → Run Script（放在 Compile Sources 上方） | `cd "$SRCROOT/.." && ./gradlew :shared:linkDebugFrameworkIosX64` |
| 2 | Build Settings → Framework Search Paths | `$(SRCROOT)/../shared/build/bin/iosX64/debugFramework` |
| 3 | Build Phases → Link Binary With Libraries | 添加 `shared.framework` |
| 4 | Build Settings → Other Linker Flags | `$(inherited)` + `-ObjC` + `-framework shared` |
| 5 | 移除 Embed Frameworks 中的 shared.framework（static 不需要） | - |

---

## 运行方式

### Android

```bash
cd KMPDemo
./gradlew :androidApp:assembleDebug
```

### iOS

1. 确保已编译 iOS framework：
   ```bash
   # Intel Mac
   ./gradlew :shared:linkDebugFrameworkIosX64
   # Apple Silicon
   ./gradlew :shared:linkDebugFrameworkIosSimulatorArm64
   ```
2. Xcode 打开 `iosApp/iosApp.xcodeproj`
3. 选择 iOS Simulator，Run

### 构建产物

```
shared/build/bin/
├── iosX64/debugFramework/shared.framework/          # Intel Mac
├── iosSimulatorArm64/debugFramework/shared.framework/ # Apple Silicon
└── iosArm64/debugFramework/shared.framework/        # 真机
```

## 技术标签

`Kotlin Multiplatform` `KMP` `expect/actual` `Kotlin/Native` `Gradle` `Xcode` `Static Framework` `XCFramework` `架构兼容性` `iosX64` `iosSimulatorArm64` `OTHER_LDFLAGS` `Framework Search Paths`
