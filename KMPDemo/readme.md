# KMP Demo - iOS 集成踩坑记录

## 项目结构

```
KMPDemo/
├── shared/          # KMP 共享模块 (expect/actual)
├── androidApp/      # Android 宿主
├── iosApp/          # iOS 宿主 (Xcode project)
└── readme.md
```

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

- Intel Mac：链接 `iosX64` 产物
  ```
  $(SRCROOT)/../shared/build/bin/iosX64/debugFramework
  ```
- Apple Silicon Mac：链接 `iosSimulatorArm64` 产物
  ```
  $(SRCROOT)/../shared/build/bin/iosSimulatorArm64/debugFramework
  ```

Run Script 中也对应修改：
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

在 `gradle.properties` 中添加或传入参数：
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

### Android（已验证）

```bash
cd KMPDemo
./gradlew :androidApp:assembleDebug
```

### iOS

1. 确保已编译 iOS framework：
   ```bash
   ./gradlew :shared:linkDebugFrameworkIosX64   # Intel Mac
   # 或
   ./gradlew :shared:linkDebugFrameworkIosSimulatorArm64  # Apple Silicon
   ```
2. Xcode 打开 `iosApp/iosApp.xcodeproj`
3. 选择 iOS Simulator，Run
