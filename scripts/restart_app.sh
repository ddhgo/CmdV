#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_PATH="${ROOT_DIR}/CmdV.xcodeproj"
SCHEME="CmdV"
CONFIGURATION="${1:-Debug}"
DERIVED_DATA="${ROOT_DIR}/build/DerivedData"
DESTINATION="platform=macOS"
APP_PATH="${DERIVED_DATA}/Build/Products/${CONFIGURATION}/CmdV.app"

command -v xcodebuild >/dev/null 2>&1 || {
    echo "Error: xcodebuild not found." >&2
    exit 1
}

if [ ! -d "${ROOT_DIR}/CmdV.xcodeproj" ]; then
    echo "Error: CmdV.xcodeproj not found in ${ROOT_DIR}." >&2
    exit 1
fi

echo "[1/3] Build"
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -destination "$DESTINATION" \
    clean build

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found: $APP_PATH" >&2
    exit 1
fi

echo "[2/3] Kill running instance"
pkill -x CmdV || true
sleep 0.3

echo "[3/3] Launch from exact artifact"
if ! open -n "$APP_PATH"; then
    echo "open(1) returned an error; launching executable directly as fallback"
    nohup "$APP_PATH/Contents/MacOS/CmdV" >/dev/null 2>&1 &
fi
