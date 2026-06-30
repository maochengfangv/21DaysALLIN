
## 一键打包 / 产物重命名 / 资源压缩（本地脚本）

- 目标：在 macOS 上对 iOS 工程执行构建/归档/导出（可选）、并对产物按版本号重命名；支持可选的资源优化（如果本机装了 pngquant/jpegoptim 等工具）。
- 入口脚本：ci/build_ios.py

### 常用命令（示例）

```bash
python3 ci/build_ios.py \
  --project LowLevelFoundDemo/LowLevelFoundDemo.xcodeproj \
  --scheme LowLevelFoundDemo \
  --configuration Release \
  --output build_out \
  --rename
```

- 若需要导出 ipa（需要签名与 ExportOptions.plist）：

```bash
python3 ci/build_ios.py \
  --project LowLevelFoundDemo/LowLevelFoundDemo.xcodeproj \
  --scheme LowLevelFoundDemo \
  --configuration Release \
  --archive \
  --export-options ci/ExportOptions.plist \
  --output build_out \
  --rename
```

## CI 简易自动化脚本

- 目标：给任意 macOS CI runner 一条命令执行构建 + 输出产物目录。
- 入口脚本：ci/ci_build.sh

```bash
bash ci/ci_build.sh LowLevelFoundDemo/LowLevelFoundDemo.xcodeproj LowLevelFoundDemo Release
```

- 环境变量（可选）：
  - OUTPUT_DIR：产物输出目录（默认 build_out）
  - EXPORT_OPTIONS_PLIST：若设置则会走 archive + export

## 灰度发布 & 回滚操作手册（本地模拟）

### 目标与边界

- 目标：在 App 内用本地配置模拟“灰度发布（多版本逻辑）→ 线上故障 → 硬编码回滚兜底”。
- 边界：这里是演示模型，不依赖真实后端；用 UserDefaults 充当本地配置来源。

### 概念映射

- Stable：稳定版本（老逻辑分支）
- Canary：灰度版本（新逻辑分支）
- Fault：模拟线上发布后的异常（例如崩溃、关键接口异常、数据不兼容）
- Rollback(hardcoded)：在代码里显式写死的兜底分支（发生异常时强制回落到 Stable）

### 操作步骤

1. 启动 App，进入 "7. 灰度发布与回滚（本地模拟）"。
2. 选择 Variant：
   - 选 Stable：直接走稳定逻辑。
   - 选 Canary：尝试走灰度逻辑。
3. 选择 Fault：
   - 选 OK：灰度逻辑正常执行。
   - 选 Fault：模拟灰度逻辑发生异常。
4. 点击 Apply：
   - 页面会展示 selected/effective/reason。
   - 若 Canary + Fault：effective 会回落为 Stable，reason 显示 rollback(hardcoded)。
5. 点击 Reset：清空本地配置，回到默认（Stable + OK）。

### 回滚策略（演示用）

- 回滚触发：灰度分支执行抛错（模拟）
- 回滚动作：强制执行 Stable 分支渲染
- 回滚观测：UI 上同时显示 selected 与 effective，避免“配置是 Canary 但实际已经回滚”的误判
