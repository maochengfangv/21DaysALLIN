要在你这个项目里“新增一个 TurboModule + 新增一个 Fabric Native Component”，流程可以按 **Spec → Codegen → Native 实现 → 注册/编译验证** 走。你现在已经有一套可参考的样板（`InterviewTurboModule` + `InterviewFabricCard`），新增时照这个模式复制一份最稳。

下面按你项目现状（`codegenConfig.name = InterviewNativeKit`，`jsSrcsDir = src/native/specs`）给出最小操作步骤。

---

## 1) 新增 TurboModule（再加一个）

### 1.1 写 TS Spec（JS 侧契约）
- 在目录：`src/native/specs/` 下新增一个 spec 文件  
  参考：[NativeInterviewTurboModule.ts](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/src/native/specs/NativeInterviewTurboModule.ts)

示例要点（你照着改名即可）：
- `TurboModuleRegistry.get<Spec>('YourNewTurboModuleName')`
- 方法签名只写你需要的：sync/async/void/返回对象都支持（跟你现在的 demo 一样）

### 1.2 JS 包装层（可选，但推荐）
- 在 `src/native/` 增加一个导出文件（类似 [InterviewTurboModule.ts](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/src/native/InterviewTurboModule.ts)）
- 主要为了统一判空、后续迁移更清晰

### 1.3 更新 codegenConfig（关键：让 iOS provider 知道新模块类名）
在 [package.json](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/package.json) 的 `codegenConfig.ios.modules` 里新增一项：

- key：**模块名**（必须等于 `TurboModuleRegistry.get('...')` 里的名字）
- `className`：iOS 原生实现的 ObjC 类名（下面 1.5 会实现）

例如：
```json
"ios": {
  "modules": {
    "InterviewTurboModule": { "className": "InterviewTurboModule" },
    "YourNewTurboModuleName": { "className": "YourNewTurboModule" }
  }
}
```

Android 不需要在这里写 module 列表（它通过 Java/Kotlin + Package 注册），但同一份 spec 会参与 Android codegen 生成 Java Spec。

### 1.4 Android 原生实现（Kotlin）
参考现有：
- [InterviewTurboModule.kt](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/android/app/src/main/java/com/myrnapp01/nativekit/InterviewTurboModule.kt)
- 生成的 Spec（编译后会出现）：`android/app/build/generated/source/codegen/java/com/myrnapp01/codegen/...Spec.java`

做法：
- 新建 `YourNewTurboModule.kt`
- `class YourNewTurboModule(...) : NativeYourNewTurboModuleSpec(reactContext)`
- 实现 spec 里的方法

### 1.5 Android 注册（BaseReactPackage）
参考：
- [InterviewDemoPackage.kt](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/android/app/src/main/java/com/myrnapp01/nativekit/InterviewDemoPackage.kt)

需要改两处：
- `getModule(name, reactContext)` 里 `when(name)` 新增分支返回你的新模块实例
- `getReactModuleInfoProvider()` 的 map 里新增你的模块条目

### 1.6 iOS 原生实现（ObjC++）
参考：
- [InterviewTurboModule.mm](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/native/InterviewNativeKit/ios/InterviewTurboModule.mm)
- 生成的头（pod install 后）：`ios/build/generated/ios/ReactCodegen/InterviewNativeKit/InterviewNativeKit.h`

做法：
- 新建 `YourNewTurboModule.mm`
- `@interface YourNewTurboModule : NSObject <NativeYourNewTurboModuleSpec> @end`
- `RCT_EXPORT_MODULE(YourNewTurboModuleName)`（名字要和 JS 侧一致）
- 实现方法
- 实现 `getTurboModule:` 返回 `NativeYourNewTurboModuleSpecJSI`

---

## 2) 新增 Fabric Native Component（再加一个原生组件）

### 2.1 写 TS Component Spec
在 `src/native/specs/` 新建文件，参考：
- [InterviewFabricCardNativeComponent.ts](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/src/native/specs/InterviewFabricCardNativeComponent.ts)

要点：
- `export interface NativeProps extends ViewProps { ... }`
- `codegenNativeComponent<NativeProps>('YourNewComponentName')`

注意：
- `width/height` 这种布局走 `style`（ViewProps），不用你自己写原生 setter
- 真正需要原生处理的属性（比如 label、颜色、圆角等）才放到 props 里

### 2.2 更新 package.json 的 codegenConfig（让 iOS third-party components provider 注册）
在 `codegenConfig.ios.components` 增加一项：

- key：组件名（必须等于 `codegenNativeComponent('...')` 的名字）
- `className`：iOS Fabric ComponentView 的类名

例如：
```json
"ios": {
  "components": {
    "InterviewFabricCard": { "className": "InterviewFabricCardComponentView" },
    "YourNewComponentName": { "className": "YourNewComponentView" }
  }
}
```

### 2.3 Android 原生实现
参考现有：
- [InterviewFabricCardView.kt](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/android/app/src/main/java/com/myrnapp01/nativekit/InterviewFabricCardView.kt)
- [InterviewFabricCardManager.kt](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/android/app/src/main/java/com/myrnapp01/nativekit/InterviewFabricCardManager.kt)
- 生成的接口/Delegate（codegen 后）：
  - `android/app/build/generated/source/codegen/java/com/facebook/react/viewmanagers/YourNewComponentManagerInterface.java`
  - `...ManagerDelegate.java`

做法：
- 新建 `YourNewView.kt`
- 新建 `YourNewManager.kt`：
  - `SimpleViewManager<YourNewView>()`
  - `implements YourNewComponentManagerInterface<YourNewView>`
  - `delegate = YourNewComponentManagerDelegate(this)`
  - 为每个自定义 prop 实现 `setXxx(...)`

### 2.4 Android 注册 view manager
在 [InterviewDemoPackage.kt](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/android/app/src/main/java/com/myrnapp01/nativekit/InterviewDemoPackage.kt) 的 `createViewManagers` 列表里加上新 Manager。

### 2.5 iOS 原生实现（Fabric ComponentView）
参考现有：
- [InterviewFabricCardComponentView.mm](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/native/InterviewNativeKit/ios/InterviewFabricCardComponentView.mm)

做法：
- 新建 `YourNewComponentView.h/.mm`
- 继承 `RCTViewComponentView`
- 实现：
  - `+ (ComponentDescriptorProvider)componentDescriptorProvider`
  - `- (void)updateProps:oldProps:` 处理自定义 props
  - `- layoutSubviews`（根据 bounds 布局子 view）

---

## 3) 怎么触发 Codegen 生成（你新增 spec 后必须做）

### iOS
`pod install` 会触发 codegen（你之前 verbose 已经看到它跑了）：

```bash
cd /Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/ios
bundle exec pod install
```

### Android
跑生成任务（会在 `android/app/build/generated/source/codegen` 看到新产物）：

```bash
cd /Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/android
./gradlew :app:generateCodegenArtifactsFromSchema
```

---

## 4) 最容易踩坑的“对齐点”（新增时一定核对）
- TurboModule 名字必须一致：
  - `TurboModuleRegistry.get('X')`
  - `RCT_EXPORT_MODULE(X)`
  - Android `Spec.NAME` / `@ReactModule(name = X)`
- Fabric 组件名字必须一致：
  - `codegenNativeComponent('X')`
  - Android `ViewManager.getName() == X`
  - iOS `RCTThirdPartyComponentsProvider` 最终注册的 key 是 `X`（来自你 `codegenConfig.ios.components`）
- iOS `className` 必须是你真实存在的 ObjC 类名（不是文件名）

---