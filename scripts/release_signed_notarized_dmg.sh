#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/CmdV.xcodeproj"
SCHEME="CmdV"
CONFIGURATION="Release"
DERIVED_DATA_PATH="${ROOT_DIR}/build/ReleaseDerivedData"
ARCHIVE_PATH="${ROOT_DIR}/build/archive/CmdV.xcarchive"
OUTPUT_DIR="${ROOT_DIR}/dist/release"
SKIP_ARCHIVE=0
SKIP_NOTARIZE=0
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APP_SIGN_IDENTITY="${APP_SIGN_IDENTITY:-}"
APPLE_ID="${APPLE_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

usage() {
  cat <<'USAGE'
Usage: scripts/release_signed_notarized_dmg.sh [options]

Builds signed archive, creates DMG, notarizes, and staples.

Options:
  --project <path>          Xcode project path (default: CmdV.xcodeproj)
  --scheme <name>           Scheme name (default: CmdV)
  --configuration <name>    Build configuration (default: Release)
  --derived-data <path>     Derived data path (default: build/ReleaseDerivedData)
  --archive-path <path>     Archive output path (default: build/archive/CmdV.xcarchive)
  --output <path>           DMG output directory (default: dist/release)
  --team-id <id>            Apple team id (or APPLE_TEAM_ID env)
  --sign-identity <name>    Signing identity (or APP_SIGN_IDENTITY env)
  --notary-profile <name>   notarytool keychain profile (or NOTARY_PROFILE env)
  --apple-id <email>        Apple ID for notarization (or APPLE_ID env)
  --apple-password <value>  App-specific password (or APPLE_APP_SPECIFIC_PASSWORD env, not recommended in shell history)
  --skip-archive            Skip archive step and use existing archive path
  --skip-notarize           Skip notarization/stapling (build + sign + DMG only)
  -h, --help                Show help

Examples:
  APPLE_TEAM_ID=<YOUR_TEAM_ID> APP_SIGN_IDENTITY="Developer ID Application: Your Name (<YOUR_TEAM_ID>)" \
  NOTARY_PROFILE=CmdVNotary scripts/release_signed_notarized_dmg.sh

  # Preferred: set NOTARY_PROFILE first. If you must use APPLE_ID/password,
  # export them in a secure shell session and avoid committing shell history.
  APPLE_TEAM_ID=<YOUR_TEAM_ID> APP_SIGN_IDENTITY="Developer ID Application: Your Name (<YOUR_TEAM_ID>)" \
  scripts/release_signed_notarized_dmg.sh --notary-profile CmdVNotary
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
    --archive-path)
      ARCHIVE_PATH="$2"
      shift 2
      ;;
    --output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --team-id)
      APPLE_TEAM_ID="$2"
      shift 2
      ;;
    --sign-identity)
      APP_SIGN_IDENTITY="$2"
      shift 2
      ;;
    --notary-profile)
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --apple-id)
      APPLE_ID="$2"
      shift 2
      ;;
    --apple-password)
      APPLE_APP_SPECIFIC_PASSWORD="$2"
      shift 2
      ;;
    --skip-archive)
      SKIP_ARCHIVE=1
      shift
      ;;
    --skip-notarize)
      SKIP_NOTARIZE=1
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

if [[ -z "$APPLE_TEAM_ID" ]]; then
  echo "Missing team id. Set APPLE_TEAM_ID or use --team-id." >&2
  exit 1
fi

if [[ -z "$APP_SIGN_IDENTITY" ]]; then
  echo "Missing signing identity. Set APP_SIGN_IDENTITY or use --sign-identity." >&2
  exit 1
fi

if [[ "$SKIP_NOTARIZE" -eq 0 ]]; then
  if [[ -z "$NOTARY_PROFILE" && ( -z "$APPLE_ID" || -z "$APPLE_APP_SPECIFIC_PASSWORD" ) ]]; then
    echo "Missing notarization credentials." >&2
    echo "Set NOTARY_PROFILE, or set APPLE_ID + APPLE_APP_SPECIFIC_PASSWORD." >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$OUTPUT_DIR"

if [[ "$SKIP_ARCHIVE" -eq 0 ]]; then
  echo "[1/7] Archiving signed app"
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -archivePath "$ARCHIVE_PATH" \
    DEVELOPMENT_TEAM="$APPLE_TEAM_ID" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$APP_SIGN_IDENTITY" \
    CODE_SIGNING_ALLOWED=YES \
    CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
    ENABLE_HARDENED_RUNTIME=YES \
    archive
else
  echo "[1/7] Skipping archive"
fi

APP_PATH="${ARCHIVE_PATH}/Products/Applications/CmdV.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "Archive app not found: $APP_PATH" >&2
  exit 1
fi

echo "[2/7] Verifying app signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
spctl -a -vv "$APP_PATH"

SIGNATURE_INFO="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 || true)"
if echo "$SIGNATURE_INFO" | rg -q 'TeamIdentifier=not set'; then
  echo "Refusing to continue: app is not Developer ID signed (TeamIdentifier missing)." >&2
  exit 1
fi
if ! echo "$SIGNATURE_INFO" | rg -q 'Runtime Version='; then
  echo "Refusing to continue: Hardened Runtime is not enabled for the archived app." >&2
  exit 1
fi

ENTITLEMENTS_TMP="$(mktemp "${TMPDIR:-/tmp}/cmdv-entitlements.XXXXXX.plist")"
if codesign -d --entitlements :- "$APP_PATH" >"$ENTITLEMENTS_TMP" 2>/dev/null; then
  GET_TASK_ALLOW=$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.get-task-allow' "$ENTITLEMENTS_TMP" 2>/dev/null || true)
  if [[ "$GET_TASK_ALLOW" == "true" || "$GET_TASK_ALLOW" == "1" ]]; then
    rm -f "$ENTITLEMENTS_TMP"
    echo "Refusing to continue: com.apple.security.get-task-allow must be false in release." >&2
    exit 1
  fi
fi
rm -f "$ENTITLEMENTS_TMP"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")
DMG_NAME="CmdV-${VERSION}.dmg"
DMG_PATH="${OUTPUT_DIR}/${DMG_NAME}"

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cmdv-release-stage.XXXXXX")"
cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

echo "[3/7] Preparing DMG staging"
cp -R "$APP_PATH" "$STAGING_DIR/CmdV.app"
ln -s /Applications "$STAGING_DIR/Applications"

if [[ -f "$DMG_PATH" ]]; then
  rm -f "$DMG_PATH"
fi

echo "[4/7] Creating DMG"
hdiutil create \
  -volname "CmdV" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ "$SKIP_NOTARIZE" -eq 1 ]]; then
  echo "[5/7] Notarization skipped"
  echo "[6/7] Stapling skipped"
  echo "[7/7] Done"
  echo "Release DMG: $DMG_PATH"
  exit 0
fi

echo "[5/7] Submitting DMG for notarization"
if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
else
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APPLE_APP_SPECIFIC_PASSWORD" \
    --team-id "$APPLE_TEAM_ID" \
    --wait
fi

echo "[6/7] Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"

echo "[7/7] Final validation"
xcrun stapler validate "$DMG_PATH"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

echo "Release DMG ready: $DMG_PATH"
