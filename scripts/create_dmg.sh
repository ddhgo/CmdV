#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/CmdV.xcodeproj"
SCHEME="CmdV"
CONFIGURATION="Release"
DERIVED_DATA_PATH="${ROOT_DIR}/build/DerivedData"
OUTPUT_DIR="${ROOT_DIR}/dist"
SKIP_BUILD=0
ALLOW_INSECURE_RELEASE=0

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
  --allow-insecure-release Allow unsigned/non-notarizable Release DMG (internal use only)
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
    --allow-insecure-release)
      ALLOW_INSECURE_RELEASE=1
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
  echo "[1/5] Clean build ${SCHEME} (${CONFIGURATION})"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    clean build
else
  echo "[1/5] Skipping build"
fi

APP_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/CmdV.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  echo "Run without --skip-build first, or adjust --derived-data/--configuration." >&2
  exit 1
fi

echo "[2/5] Validating release signing profile"
if [[ "$CONFIGURATION" == "Release" && "$ALLOW_INSECURE_RELEASE" -eq 0 ]]; then
  SIGNATURE_INFO="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)"
  if echo "$SIGNATURE_INFO" | rg -q 'TeamIdentifier=not set'; then
    echo "Refusing to create Release DMG from ad-hoc/local signature." >&2
    echo "Use scripts/release_signed_notarized_dmg.sh for distribution, or pass --allow-insecure-release for internal tests." >&2
    exit 1
  fi

  if ! echo "$SIGNATURE_INFO" | rg -q 'Runtime Version='; then
    echo "Refusing to create Release DMG: Hardened Runtime is not enabled." >&2
    echo "Use scripts/release_signed_notarized_dmg.sh for distribution." >&2
    exit 1
  fi

  ENTITLEMENTS_TMP="$(mktemp "${TMPDIR:-/tmp}/cmdv-entitlements.XXXXXX.plist")"
  if codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS_TMP" 2>/dev/null; then
    GET_TASK_ALLOW=$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$ENTITLEMENTS_TMP" 2>/dev/null || true)
    if [[ "$GET_TASK_ALLOW" == "true" || "$GET_TASK_ALLOW" == "1" ]]; then
      rm -f "$ENTITLEMENTS_TMP"
      echo "Refusing to create Release DMG: com.apple.security.get-task-allow must be false." >&2
      echo "Use scripts/release_signed_notarized_dmg.sh for distribution." >&2
      exit 1
    fi
  fi
  rm -f "$ENTITLEMENTS_TMP"
else
  echo "Skipping strict release signing validation (non-Release build or override enabled)."
fi

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
DMG_NAME="CmdV-${VERSION}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cmdv-dmg-stage.XXXXXX")"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "[3/5] Preparing staging files"
cp -R "$APP_PATH" "$STAGING_DIR/CmdV.app"
ln -s /Applications "$STAGING_DIR/Applications"

if [[ -f "$DMG_PATH" ]]; then
  rm -f "$DMG_PATH"
fi

echo "[4/5] Creating DMG"
hdiutil create \
  -volname "CmdV" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "[5/5] Done"
echo "DMG created at: $DMG_PATH"
