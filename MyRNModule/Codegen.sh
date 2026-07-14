#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# IOSRNContainer 路径（与 MyRNModule 同级）
IOS_CONTAINER_DIR="$SCRIPT_DIR/../IOSRNContainer"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

PLATFORM="${1:-ios}"

# ---------- 校验 ----------

check_specs() {
  if [ ! -d "specs" ] || [ -z "$(ls -A specs 2>/dev/null)" ]; then
    log_error "specs/ 目录为空或不存在。请先创建 JS Spec 文件。"
    echo "  Example specs:"
    echo "    specs/NativeCounter.ts      (Turbo Module)"
    echo "    specs/NativeColoredView.ts  (Fabric Component)"
    exit 1
  fi
  log_info "Found $(ls specs/*.ts 2>/dev/null | wc -l | tr -d ' ') spec file(s) in specs/"
}

check_ios_container() {
  if [ ! -d "$IOS_CONTAINER_DIR" ]; then
    log_error "IOSRNContainer 目录不存在: $IOS_CONTAINER_DIR"
    exit 1
  fi
  if [ ! -f "$IOS_CONTAINER_DIR/Podfile" ]; then
    log_error "IOSRNContainer/Podfile 不存在"
    exit 1
  fi
  log_info "IOSRNContainer 路径: $IOS_CONTAINER_DIR"
}

# ---------- iOS Codegen（在 IOSRNContainer 中执行） ----------

codegen_ios() {
  check_specs
  check_ios_container

  log_info "在 IOSRNContainer 中执行 pod install（触发 codegen）..."
  cd "$IOS_CONTAINER_DIR"

  RCT_USE_TURBOMODULE=1 \
  RCT_NEW_ARCH_ENABLED=1 \
  USE_FRAMEWORKS=static \
  bundle exec pod install 2>/dev/null || pod install

  cd "$SCRIPT_DIR"

  # 将生成的 codegen 头文件拷贝到 IOSRNModule/CodegenHeaders/，让 Xcode 可以直接管理
  local CODEGEN_SRC="$IOS_CONTAINER_DIR/build/generated/ios/ReactCodegen/MyRNAppSpecs"
  local CODEGEN_DST="$IOS_CONTAINER_DIR/IOSRNModule/CodegenHeaders"
  if [ -d "$CODEGEN_SRC" ]; then
    mkdir -p "$CODEGEN_DST"
    cp "$CODEGEN_SRC"/*.h "$CODEGEN_DST/" 2>/dev/null || true
    log_info "Codegen 头文件已拷贝到 IOSRNModule/CodegenHeaders/"
    ls "$CODEGEN_DST"
  else
    log_warn "未找到 codegen 产物: $CODEGEN_SRC"
  fi

  # 自动将 IOSRNModule 目录加入 Xcode 项目
  local XCODEPROJ="$IOS_CONTAINER_DIR/IOSRNContainer.xcodeproj"
  if [ -d "$XCODEPROJ" ]; then
    ruby -e "
      require 'xcodeproj'
      project = Xcodeproj::Project.open('$XCODEPROJ')

      # 在项目根 group 下查找或创建 IOSRNModule group
      main_group = project.main_group
      module_group = main_group.children.find { |c|
        c.respond_to?(:name) && c.name == 'IOSRNModule'
      }
      module_group ||= main_group.new_group('IOSRNModule', './IOSRNModule')

      # 添加 .h/.mm 文件引用
      srcdir = '$IOS_CONTAINER_DIR/IOSRNModule'
      Dir.glob(File.join(srcdir, '*.{h,mm}')).each do |file|
        name = File.basename(file)
        existing = module_group.files.any? { |f| f.path == name }
        unless existing
          ref = module_group.new_file(name)
          if name.end_with?('.mm')
            project.targets.each do |t|
              next unless t.name == 'IOSRNContainer'
              t.source_build_phase.add_file_reference(ref)
            end
          end
        end
      end
      project.save
      puts '  Xcode 项目已更新：IOSRNModule 文件已加入编译。'
    " 2>/dev/null || log_warn "无法自动更新 Xcode 项目（可能缺少 xcodeproj gem）。请手动将 IOSRNModule/ 目录拖入 Xcode。"
  fi

  # 检查 IOSRNContainer 中的 codegen 产物
  GENERATED_DIR="$IOS_CONTAINER_DIR/build/generated/ios"
  if [ -d "$GENERATED_DIR" ]; then
    log_info "iOS codegen 产物: $GENERATED_DIR"
    echo "  TurboModule/Fabric 接口:"
    find "$GENERATED_DIR/ReactCodegen" -name "*.h" 2>/dev/null | while read f; do
      echo "    $(basename "$f")"
    done
  else
    log_warn "iOS codegen 产物未找到: $GENERATED_DIR"
  fi
}

# ---------- Android Codegen ----------

codegen_android() {
  check_specs

  ANDROID_DIR="android"
  if [ ! -d "$ANDROID_DIR" ]; then
    log_error "android/ 目录未找到."
    exit 1
  fi

  log_info "运行 Android Codegen (Gradle)..."
  cd "$ANDROID_DIR"
  ./gradlew generateCodegenArtifactsFromSchema 2>&1 | tail -20
  cd ..

  GENERATED_DIR="android/app/build/generated/source/codegen"
  if [ -d "$GENERATED_DIR" ]; then
    log_info "Android codegen 产物: $GENERATED_DIR"
  else
    log_warn "Android codegen 产物未找到: $GENERATED_DIR"
  fi
}

# ---------- JS Schema 预览 ----------

codegen_schema() {
  check_specs
  local platform="${1:-ios}"
  log_info "生成 JS Schema 预览 (platform=$platform)..."
  npx react-native codegen \
    --platform "$platform" \
    --outputPath "./codegen-out/$platform" \
    "${@:2}" 2>&1 || log_warn "Schema 生成失败；请检查 specs/ 中的语法错误"
}

# ---------- 清理 ----------

clean_codegen() {
  log_info "清理 codegen 产物..."
  rm -rf codegen-out
  rm -rf "$IOS_CONTAINER_DIR/build/generated"
  rm -rf "$IOS_CONTAINER_DIR/Pods"
  rm -rf android/app/build/generated/source/codegen
  log_info "已清理."
}

# ---------- 帮助 ----------

usage() {
  echo "Usage: ./Codegen.sh [ios|android|all|schema [platform]|clean]"
  echo ""
  echo "  ios      - 在 IOSRNContainer 中执行 pod install，触发 TurboModule + Fabric codegen"
  echo "  android  - 在 MyRNModule/android 中执行 Gradle codegen"
  echo "  all      - iOS + Android (默认)"
  echo "  schema   - 仅预览 JS Schema 生成结果"
  echo "  clean    - 清理所有 codegen 产物 (IOSRNContainer 的 build/generated 也会清理)"
  echo ""
  echo "  specs 目录:"
  echo "    specs/NativeCounter.ts       (Turbo Module)"
  echo "    specs/NativeColoredView.ts   (Fabric Component)"
  exit 0
}

# ---------- 主入口 ----------

case "$PLATFORM" in
  ios)
    codegen_ios
    ;;
  android)
    codegen_android
    ;;
  all)
    codegen_ios
    codegen_android
    ;;
  schema)
    codegen_schema "${2:-ios}"
    ;;
  clean)
    clean_codegen
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    log_error "未知命令: $PLATFORM"
    usage
    ;;
esac

log_info "Codegen 完成."
