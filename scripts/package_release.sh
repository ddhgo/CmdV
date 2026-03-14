#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/package_release.sh [--skip-build]

Builds the CmdV Release app, applies a full bundle code signature, then creates:
  build/release-artifacts/v<version>/CmdV-v<version>.zip
  build/release-artifacts/v<version>/CmdV-v<version>.zip.sha256

Environment:
  CMDV_SIGN_IDENTITY  Code signing identity to use. Defaults to "-" for ad-hoc signing.
  DEVELOPER_DIR       Xcode developer directory. Defaults to /Applications/Xcode.app/... when present.
EOF
}

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skip_build=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      skip_build=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

build_root="$root_dir/build/codex-release"
derived_data="$root_dir/build/codex-derived-release"
product_dir="$build_root/Build/Products/Release"
app_path="$product_dir/CmdV.app"

if [[ "$skip_build" -eq 0 ]]; then
  if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
  fi

  if ! xcodebuild -version >/dev/null 2>&1; then
    echo "xcodebuild is unavailable. Install Xcode or set DEVELOPER_DIR to a full Xcode app." >&2
    exit 1
  fi

  rm -rf "$build_root" "$derived_data"
  mkdir -p "$product_dir"

  xcodebuild \
    -project "$root_dir/CmdV.xcodeproj" \
    -scheme CmdV \
    -configuration Release \
    -derivedDataPath "$derived_data" \
    CONFIGURATION_BUILD_DIR="$product_dir" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build
fi

if [[ ! -d "$app_path" ]]; then
  echo "Release app not found at $app_path" >&2
  exit 1
fi

plist_path="$app_path/Contents/Info.plist"
bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist_path")"
marketing_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist_path")"
artifact_dir="$root_dir/build/release-artifacts/v$marketing_version"
zip_path="$artifact_dir/CmdV-v$marketing_version.zip"
checksum_path="$zip_path.sha256"
sign_identity="${CMDV_SIGN_IDENTITY:--}"

stage_dir="$(mktemp -d "$root_dir/build/release-stage.XXXXXX")"
spctl_report_path="$(mktemp /tmp/cmdv-spctl.XXXXXX)"
trap 'rm -rf "$stage_dir"; rm -f "$spctl_report_path"' EXIT
cp -R "$app_path" "$stage_dir/CmdV.app"
staged_app="$stage_dir/CmdV.app"

if codesign --display "$staged_app" >/dev/null 2>&1; then
  codesign --remove-signature "$staged_app"
fi

codesign \
  --force \
  --deep \
  --sign "$sign_identity" \
  --timestamp=none \
  --identifier "$bundle_id" \
  "$staged_app"

codesign --verify --deep --strict "$staged_app"
signature_report="$(codesign -dv --verbose=4 "$staged_app" 2>&1)"

if ! grep -q "Identifier=$bundle_id" <<<"$signature_report"; then
  echo "Signed app identifier did not bind to $bundle_id" >&2
  echo "$signature_report" >&2
  exit 1
fi

if ! grep -q "Info.plist entries=" <<<"$signature_report"; then
  echo "Signed app is missing a bound Info.plist" >&2
  echo "$signature_report" >&2
  exit 1
fi

if ! grep -q "Sealed Resources version=" <<<"$signature_report"; then
  echo "Signed app is missing sealed resources" >&2
  echo "$signature_report" >&2
  exit 1
fi

mkdir -p "$artifact_dir"
rm -f "$zip_path" "$checksum_path"
ditto -c -k --sequesterRsrc --keepParent "$staged_app" "$zip_path"
shasum -a 256 "$zip_path" > "$checksum_path"

echo "Packaged CmdV v$marketing_version ($build_number)"
echo "Signing identity: $sign_identity"
echo "Artifact: $zip_path"
echo "Checksum: $checksum_path"
echo
echo "$signature_report"

if ! spctl -a -vv "$staged_app" >"$spctl_report_path" 2>&1; then
  echo
  echo "spctl assessment:"
  cat "$spctl_report_path"
fi
