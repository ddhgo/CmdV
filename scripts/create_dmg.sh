#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/CmdV.xcodeproj"
SCHEME="CmdV"
CONFIGURATION="Release"
DERIVED_DATA_PATH="${ROOT_DIR}/build/DerivedData"
OUTPUT_DIR="${ROOT_DIR}/dist"
SKIP_BUILD=0

usage() {
  cat <<'USAGE'
Usage: scripts/create_dmg.sh [options]

Options:
  --project <path>         Xcode project path (default: CmdV.xcodeproj)
  --scheme <name>          Scheme name (default: CmdV)
  --configuration <name>   Build configuration (default: Release)
  --derived-data <path>    Derived data output (default: build/DerivedData)
  --output <path>          DMG output directory (default: dist)
  --skip-build             Skip xcodebuild and package existing .app
  -h, --help               Show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      PROJECT_PATH="$2"
      shift 2
      ;;
    --scheme)
      SCHEME="$2"
      shift 2
      ;;
    --configuration)
      CONFIGURATION="$2"
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA_PATH="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --skip-build)
      SKIP_BUILD=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

mkdir -p "$OUTPUT_DIR"

if [[ "$SKIP_BUILD" -eq 0 ]]; then
  echo "[1/4] Building ${SCHEME} (${CONFIGURATION})"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
else
  echo "[1/4] Skipping build"
fi

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/CmdV.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  echo "Run without --skip-build first, or adjust --derived-data/--configuration." >&2
  exit 1
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
DMG_NAME="CmdV-${VERSION}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cmdv-dmg-stage.XXXXXX")"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "[2/4] Preparing staging files"
cp -R "$APP_PATH" "$STAGING_DIR/CmdV.app"
ln -s /Applications "$STAGING_DIR/Applications"

if [[ -f "$DMG_PATH" ]]; then
  rm -f "$DMG_PATH"
fi

echo "[3/4] Creating DMG"
hdiutil create \
  -volname "CmdV" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "[4/4] Done"
echo "DMG created at: $DMG_PATH"
