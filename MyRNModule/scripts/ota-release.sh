#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

if [ "$#" -lt 4 ]; then
  echo "用法: $0 <platform> <channel> <version> <public_base_url> [description]"
  echo "示例: $0 android production 1.0.0 https://cdn.example.com/ota 首个生产热更新"
  exit 1
fi

PLATFORM="$1"
CHANNEL="$2"
VERSION="$3"
PUBLIC_BASE_URL="${4%/}"
DESCRIPTION="${5:-}"

LABEL="${OTA_LABEL:-v$(date +%Y%m%d%H%M%S)}"
ENTRY_FILE="${OTA_ENTRY_FILE:-index.js}"
OUTPUT_DIR="$PROJECT_DIR/build/ota/$PLATFORM/$VERSION"
PACKAGE_DIR="$OUTPUT_DIR/package"
ASSETS_DIR="$PACKAGE_DIR/assets"
PACKAGE_FILE="$OUTPUT_DIR/package.zip"
MANIFEST_FILE="$OUTPUT_DIR/manifest.json"

case "$PLATFORM" in
  android)
    BUNDLE_FILE="index.android.bundle"
    ;;
  ios)
    BUNDLE_FILE="main.jsbundle"
    ;;
  *)
    echo "错误: 不支持的平台 $PLATFORM"
    exit 1
    ;;
esac

echo "[OTA] 清理输出目录: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$ASSETS_DIR"

echo "[OTA] 打包 React Native bundle"
npx react-native bundle \
  --platform "$PLATFORM" \
  --dev false \
  --entry-file "$ENTRY_FILE" \
  --bundle-output "$PACKAGE_DIR/$BUNDLE_FILE" \
  --assets-dest "$ASSETS_DIR"

echo "[OTA] 压缩更新包"
(cd "$PACKAGE_DIR" && zip -qr "$PACKAGE_FILE" .)

PACKAGE_URL="$PUBLIC_BASE_URL/$PLATFORM/$VERSION/package.zip"

echo "[OTA] 生成 manifest"
MANIFEST_ARGS=(
  --platform "$PLATFORM"
  --channel "$CHANNEL"
  --version "$VERSION"
  --label "$LABEL"
  --package-url "$PACKAGE_URL"
  --package-file "$PACKAGE_FILE"
  --bundle-file "$BUNDLE_FILE"
  --bundle-file-path "$PACKAGE_DIR/$BUNDLE_FILE"
  --output "$MANIFEST_FILE"
  --description "$DESCRIPTION"
  --rollout "${OTA_ROLLOUT:-100}"
  --package-type "${OTA_PACKAGE_TYPE:-full}"
)

if [ -n "${OTA_MIN_NATIVE_VERSION:-}" ]; then
  MANIFEST_ARGS+=(--min-native-version "$OTA_MIN_NATIVE_VERSION")
fi

if [ -n "${OTA_PRIVATE_KEY_PATH:-}" ]; then
  MANIFEST_ARGS+=(--private-key "$OTA_PRIVATE_KEY_PATH")
fi

if [ -n "${OTA_MANDATORY:-}" ]; then
  MANIFEST_ARGS+=(--mandatory "$OTA_MANDATORY")
fi

node ./scripts/create-ota-manifest.mjs "${MANIFEST_ARGS[@]}"

echo "[OTA] 产物已生成:"
echo "  Package : $PACKAGE_FILE"
echo "  Manifest: $MANIFEST_FILE"
echo ""
echo "[OTA] 下一步:"
echo "  1. 上传 $OUTPUT_DIR 到你的 CDN / 对象存储"
echo "  2. 将 manifest 暴露为固定 URL，例如:"
echo "     $PUBLIC_BASE_URL/$PLATFORM/$VERSION/manifest.json"
echo "  3. 在 src/config/hotUpdate.ts 中填入 manifestURL 与 publicKey"
