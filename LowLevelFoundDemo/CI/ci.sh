#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${1:-}"
SCHEME="${2:-}"
CONFIGURATION="${3:-Release}"
OUTPUT_DIR="${OUTPUT_DIR:-build_out}"
EXPORT_OPTIONS_PLIST="${EXPORT_OPTIONS_PLIST:-}"

if [[ -z "$PROJECT_PATH" || -z "$SCHEME" ]]; then
  echo "usage: bash ci/ci_build.sh <path_to_xcodeproj> <scheme> [configuration]" >&2
  exit 2
fi

if [[ -n "$EXPORT_OPTIONS_PLIST" ]]; then
  python3 ci/build_ios.py \
    --project "$PROJECT_PATH" \
    --scheme "$SCHEME" \
    --configuration "$CONFIGURATION" \
    --archive \
    --export-options "$EXPORT_OPTIONS_PLIST" \
    --output "$OUTPUT_DIR" \
    --rename
else
  python3 ci/build_ios.py \
    --project "$PROJECT_PATH" \
    --scheme "$SCHEME" \
    --configuration "$CONFIGURATION" \
    --output "$OUTPUT_DIR" \
    --rename \
    --zip
fi