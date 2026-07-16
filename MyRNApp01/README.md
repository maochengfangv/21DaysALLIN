# MyRNApp01 — React Native 新架构综合 Demo

## 项目概述

基于 **React Native 0.86.0 + React 19.2.3 + TypeScript 5.8**，完整展示 **New Architecture（TurboModule + Fabric）端到端开发链路**、**长列表性能优化（曝光追踪 + 懒加载 + 图片缓存）**、**Render 优化对比** 以及 **交互调度** 的综合 Demo App。包含 13 个可运行演示页面，按 RN 基础 → 性能 → 新架构 → 工程化四级递进组织。

## 项目结构

```
MyRNApp01/
├── src/
│   ├── app/
│   │   └── AppRoot.tsx                      # 自定义 Stack 导航 + 全局 ErrorBoundary + 返回键拦截
│   ├── configs/
│   │   └── demoRegistry.ts                  # 四级 Demo 目录（RN基础/性能/新架构/工程化）
│   ├── native/
│   │   ├── specs/                           # Codegen TS 入口：TurboModule + Fabric Component 声明
│   │   ├── InterviewTurboModule.ts         # TurboModule JS 包装层
│   │   └── InterviewFabricCard.tsx          # Fabric Component JS 包装组件
│   ├── pages/
│   │   ├── home/HomeScreen.tsx              # Demo 导航首页
│   │   ├── basics/                          # FlatList / Form / Network / Hooks / ErrorBoundary ...
│   │   ├── performance/                     # RenderOptimization / Interaction / PerformanceNotes
│   │   ├── architecture/                    # TurboModuleScreen / FabricViewScreen / JsiNoteScreen
│   │   └── engineering/                     # EnvConfigScreen
│   ├── hooks/
│   │   ├── useDebouncedValue.ts             # 通用防抖 Hook
│   │   └── useMountedRef.ts                 # 组件挂载状态 Ref
│   ├── services/
│   │   ├── env.ts                           # Hermes / Fabric / Bridgeless 运行时检测
│   │   ├── mockApi.ts                       # 分页 Mock API + 可注入失败
│   │   └── analytics.ts                     # 曝光/请求事件打点桩
│   ├── components/                          # Header / ImagePreviewModal 等公共组件
│   └── utils/                               # logger / stringify / getErrorMessage
├── native/
│   └── InterviewNativeKit/
│       ├── ios/                             # ObjC++ TurboModule + Fabric ComponentView + Podspec
│       └── InterviewNativeKit.podspec       # Codegen 联动配置
├── android/app/src/main/java/.../nativekit/
│   ├── InterviewTurboModule.kt              # Kotlin TurboModule（extends Codegen生成Spec）
│   ├── InterviewFabricCardView.kt           # Fabric 原生 View（GradientDrawable）
│   ├── InterviewFabricCardManager.kt        # Fabric ViewManager（Codegen Delegate 模式）
│   └── InterviewDemoPackage.kt              # Native Package 注册
├── doc/
│   ├── Exposed.md                           # 曝光追踪 + 懒请求方案文档
│   └── imagecache.md                        # 三层图片缓存架构文档
├── FabricTurboReadMe.md                     # TurboModule/Fabric 接入全流程指南
└── package.json                             # RN 0.86.0 / React 19.2.3 / codegenConfig
```

---

## 技术要点

### 一、New Architecture：TurboModule（端到端）

#### 完整 Codegen 链路

```
TS Spec (src/native/specs/NativeInterviewTurboModule.ts)
  │  TurboModuleRegistry.get<Spec>('InterviewTurboModule')
  │  methods: getDeviceInfo / getTimestamp / getTimestampAsync / logNativeMessage
  ▼
react-native-codegen (触发: pod install / gradle codegen)
  │  package.json codegenConfig 驱动 → 生成双端绑定代码
  ▼
├─ iOS  (InterviewTurboModule.mm)
│   conforms to <NativeInterviewTurboModuleSpec>  // Codegen 协议
│   getTurboModule: → NativeInterviewTurboModuleSpecJSI  // JSI 绑定
│   RCT_EXPORT_MODULE(InterviewTurboModule)
│
└─ Android (InterviewTurboModule.kt)
    @ReactModule(name = "InterviewTurboModule")
    extends NativeInterviewTurboModuleSpec(reactContext)  // Codegen 生成基类
```

#### 方法实现对比

| 方法 | 返回 | iOS 实现 | Android 实现 |
|------|------|----------|-------------|
| `getDeviceInfo` | sync `DeviceInfo` | `operatingSystemVersionString` + Bundle info | `Build.VERSION.RELEASE` + `BuildConfig` |
| `getTimestamp` | sync `Double` | `[[NSDate date] timeIntervalSince1970] * 1000` | `System.currentTimeMillis().toDouble()` |
| `getTimestampAsync` | `Promise<Double>` | `resolve(@(...))` | `promise.resolve(...)` |
| `logNativeMessage` | void | `NSLog` | `Log.i` + `Toast.makeText` |

#### CodegenConfig（package.json）

```json
{
  "codegenConfig": {
    "name": "InterviewNativeKit",
    "type": "all",
    "jsSrcsDir": "src/native/specs",
    "android": { "javaPackageName": "com.myrnapp01.codegen" },
    "ios": {
      "modules": { "InterviewTurboModule": { "className": "InterviewTurboModule" } },
      "components": { "InterviewFabricCard": { "className": "InterviewFabricCardComponentView" } }
    }
  }
}
```

---

### 二、New Architecture：Fabric Native Component

#### TS Component Spec

```typescript
// src/native/specs/InterviewFabricCardNativeComponent.ts
import codegenNativeComponent from 'react-native/Libraries/Utilities/codegenNativeComponent';

interface NativeProps extends ViewProps {
  label?: string;
  cardBackgroundColor?: ColorValue;
  cornerRadius?: Float;
  // 注意：width/height 不在此声明，走 ViewProps.style 的 Fabric 布局系统
}

export default codegenNativeComponent<NativeProps>('InterviewFabricCard');
```

#### iOS 实现（InterviewFabricCardComponentView.mm）

```objc
// 注册 ComponentDescriptor（Fabric 渲染器需要）
+ (ComponentDescriptorProvider)componentDescriptorProvider {
    return concreteComponentDescriptorProvider<InterviewFabricCardComponentDescriptor>();
}

// Fabric 核心：C++ Props → 原生 View 属性
- (void)updateProps:(const Props::Shared &)props oldProps:(const Props::Shared &)oldProps {
    const auto &newProps = *std::static_pointer_cast<const InterviewFabricCardProps>(props);

    if (!newProps.cardBackgroundColor.empty()) {
        self.backgroundColor = RCTUIColorFromSharedColor(newProps.cardBackgroundColor);
    }
    self.layer.cornerRadius = newProps.cornerRadius;
    _labelView.text = @(newProps.label.c_str());
}
```

#### Android 实现（InterviewFabricCardManager.kt）

```kotlin
// 使用 Codegen 生成的 Delegate 模式委托 prop 处理
class InterviewFabricCardManager : SimpleViewManager<InterviewFabricCardView>(),
    InterviewFabricCardManagerInterface<InterviewFabricCardView> {

    private val delegate = InterviewFabricCardManagerDelegate(this)
    override fun getDelegate() = delegate

    @ReactProp(name = "cardBackgroundColor")
    override fun setCardBackgroundColor(view: InterviewFabricCardView, value: String?) {
        view.setCardBackgroundColor(value)
    }
}
```

- **Android View**：`InterviewFabricCardView(FrameLayout)` + `GradientDrawable` 动态设置圆角和背景色
- **Android ViewManager**：Codegen 生成的 `ManagerInterface` + `ManagerDelegate`，自动委托 prop 设置

---

### 三、FlatList 性能优化体系

#### 3a. 自适应渲染参数

```typescript
const isLowTier = width <= 360 || height <= 780;

const listProps = isLowTier
  ? { initialNumToRender: 4, maxToRenderPerBatch: 2, windowSize: 3, updateCellsBatchingPeriod: 80 }
  : { initialNumToRender: 6, maxToRenderPerBatch: 4, windowSize: 5, updateCellsBatchingPeriod: 60 };
```

#### 3b. Ref 驱动的分页去重

```typescript
// 用 Ref 替代 State，避免触发额外渲染
const currentPageRef = useRef(0);
const refreshingRef = useRef(false);
const loadingMoreRef = useRef(false);
const hasMoreRef = useRef(false);
```

#### 3c. 曝光追踪状态机（Ref-based）

```
配置：EXPOSURE_VISIBLE_THRESHOLD = 35%  /  EXPOSURE_STAY_MS = 300ms

onViewableItemsChanged
  │
  ├── isViewable = true
  │   ├── 已 exposed? → 跳过
  │   ├── 已有 timer? → 跳过（防重复）
  │   └── 新建 entry → enteredAt = now → setTimeout(300ms) → confirmExposure
  │
  └── isViewable = false
      ├── 有 pending timer? → clearTimeout，删除 entry
      ├── 已 exposed? → 保留 exposed 标志，timer = null
      └── 其他 → 删除 entry
```

**核心设计**：状态机完全存在 `useRef` 中，不触发任何 setState，避免高频滚动时的不必要渲染。

#### 3d. 曝光触发懒请求（双重去重）

```typescript
// 两层去重 Set，阻止重复请求
const requestedIdsRef = useRef<Set<number>>(new Set())   // 已成功拉取
const inflightIdsRef  = useRef<Set<number>>(new Set())   // 请求进行中

// Statue 跟踪也走 Ref，只在真正变化时才 setState
const requestStatusRef = useRef<Map<number, string>>(new Map())
```

#### 3e. 图片懒挂载（Hydration）

```
markHydratedImages(viewableItems)  →  hydratedImageIds (Set)
                                              │
                                  FeedImageGrid 组件            │
                                  ├── shouldRenderImages=true   │
                                  │   → CachedImage 网格        │
                                  └── shouldRenderImages=false  │
                                      → 轻量占位 "{N} 张图片"
```

#### 3f. 微信风格图片网格布局

```
getWechatLikeRowPattern(count):
  1→[1]  2→[2]  3→[3]  4→[2,2]  5→[3,2]  6→[3,3]
  7→[3,3,1]  8→[3,3,2]  9→[3,3,3]

Singleton 图使用 SINGLE_IMAGE_WIDTH=220，双图和三图按 GRID_MAX_WIDTH 均分
最多显示 9 张，超出的按 "+N" 折叠
```

---

### 四、三层图片缓存体系

| 层级 | 机制 | 实现 |
|------|------|------|
| **HTTP Cache** | `Image` 组件 `cache: 'force-cache'` | 系统级 HTTP 缓存 |
| **Prefetch** | `Image.prefetch(uri)` + `prefetchRegistry` Map 去重 | 预热到内存 |
| **Cache Probing** | `Image.queryCache([uri])` | 查询当前缓存状态（memory/disk/disk+memory） |

```typescript
// 模块级 Map 去重
const cacheRegistry = new Map<string, FeedImageCacheSource>();   // 已知缓存源
const prefetchRegistry = new Map<string, Promise<void>>();       // 防重复预热
```

图片生命周期状态：`loading → success（带缓存 badge：MEM/DISK/PREFETCH/HTTP）→ error（重试按钮 + key 强制重挂载）`

---

### 五、Render 优化对比演示

RenderOptimizationScreen 并排展示：

| | 未优化（NonMemoBlock） | 已优化（MemoBlock） |
|---|---|---|
| 组件包装 | 无 memo | `React.memo` |
| Props 对象 | 每次新建 `{keyword, tag}` | `useMemo(() => ({keyword, tag}), [keyword])` |
| Callback | 每次新建箭头函数 | `useCallback(() => {...}, [])` |
| 无关状态更新 | 触发重渲染 | 不触发重渲染 |
| Render 计数 | 每次变化 +1 | 仅在 memo 比较变化时 +1 |

**核心原则**：`memo` + `useMemo` + `useCallback` 三件套，稳定引用传递，避免无效渲染。

---

### 六、交互调度

```typescript
// requestAnimationFrame — 下一帧执行
requestAnimationFrame(() => {
  setResult(`RAF 在下一帧执行：${Date.now()}`);
});

// InteractionManager — 交互动画结束后执行
InteractionManager.runAfterInteractions(async () => {
  await wait(120);
  setResult(`交互结束后执行：${Date.now()}`);
});
```

---

### 七、自定义导航 & 全局异常

```typescript
// 自定义 Stack 导航（无三方库依赖）
const [stack, setStack] = useState<RouteKey[]>(['home']);
const navigate = (route: RouteKey) => setStack(prev => [...prev, route]);
const goBack = () => setStack(prev => prev.length > 1 ? prev.slice(0, -1) : ['home']);

// Android 硬件返回键
BackHandler.addEventListener('hardwareBackPress', () => {
  if (stack.length > 1) { goBack(); return true; }
  return false;
});

// 全局 ErrorUtils 捕获
ErrorUtils.setGlobalHandler((error, isFatal) => {
  logger.error('GlobalError', String(error));
  setLastGlobalError(String(error));
  // 链式调用旧 handler
});
```

---

### 八、运行时环境检测

```typescript
// src/services/env.ts
hermesEnabled:      Boolean(runtime.HermesInternal)
fabricEnabled:       Boolean(runtime.nativeFabricUIManager)
bridgelessHint:      Boolean(runtime.RN$Bridgeless)
reactNativeVersion:  Platform.constants.reactNativeVersion → "0.86.0"
mode:                __DEV__ ? 'dev' : 'prod'
```

---

### 九、FabricTurboReadMe — 接入指南

[FabricTurboReadMe.md](file:///Users/maochengfang/Documents/LLMProject/21DaysALLIN/MyRNApp01/FabricTurboReadMe.md) 详细记录了 TurboModule/Fabric 组件接入的完整 Checklist：

- **TurboModule 5 步**：TS Spec → JS 包装 → package.json codegenConfig → Android（extends Spec）→ iOS（getTurboModule JSI 绑定）
- **Fabric 组件 4 步**：TS Spec → package.json codegenConfig → Android（View + ManagerInterface/Delegate）→ iOS（RCTViewComponentView + updateProps）
- **7 项命名对齐陷阱清单**：模块名/组件名/类名在 TS/iOS/Android 三端的对应关系
- **Codegen 触发命令**：`pod install`（iOS）/ `generateCodegenArtifactsFromSchema`（Android）

---

## Demo 页面列表

| 分类 | 路由 | 内容 |
|------|------|------|
| **RN 基础** | `hooks` | useState / useEffect / useRef / useMemo 示例 |
| | `flatlist` | 自适应 FlatList + 曝光追踪 + 懒请求 + 图片缓存 |
| | `form` | TextInput 表单 + 校验 + 提交 |
| | `network` | Mock API 请求 + 错误处理 |
| | `customHook` | useDebouncedValue / useMountedRef 演示 |
| | `errorBoundary` | 全局 ErrorUtils + 组件级 ErrorBoundary |
| **性能** | `renderOptimization` | memo + useMemo + useCallback 对比 |
| | `interaction` | requestAnimationFrame + InteractionManager |
| | `performanceNotes` | 性能优化要点总结 |
| **新架构** | `turboModule` | TurboModule sync/async 调用演示 |
| | `fabricView` | Fabric 组件动态 prop 更新 |
| | `jsiNote` | JSI 概念讲解 |
| **工程化** | `envConfig` | Hermes/Fabric/Bridgeless 运行时检测 |

---

## 运行方式

```bash
cd MyRNApp01

# iOS
cd ios && pod install && cd ..
npx react-native run-ios

# Android
npx react-native run-android
```

- Codegen 生成：iOS 侧 `pod install` 自动触发，Android 侧 `./gradlew :app:generateCodegenArtifactsFromSchema`
- Metro 需已启动（`npx react-native start`）
- TurboModule + Fabric 需 New Architecture 启用（项目默认开启）

## 技术标签

`React Native` `New Architecture` `TurboModule` `Fabric` `JSI` `Codegen` `FlatList` `曝光追踪` `图片缓存` `React.memo` `useCallback` `useMemo` `requestAnimationFrame` `InteractionManager` `ErrorUtils` `TypeScript` `Kotlin` `ObjC++` `podspec`
