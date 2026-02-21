#!/usr/bin/env bash

set -euo pipefail

PROFILE_NAME="${NOTARY_PROFILE_NAME:-CmdVNotary}"
APPLE_ID="${APPLE_ID:-}"
APPLE_TEAM_ID="${APPLE_TEAM_ID:-}"
APPLE_APP_SPECIFIC_PASSWORD="${APPLE_APP_SPECIFIC_PASSWORD:-}"

usage() {
  cat <<'USAGE'
Usage: scripts/setup_notary_profile.sh [options]

Stores notarization credentials in keychain for xcrun notarytool.

Options:
  --profile <name>         Keychain profile name (default: CmdVNotary)
  --apple-id <email>       Apple ID (or APPLE_ID env)
  --team-id <id>           Apple team id (or APPLE_TEAM_ID env)
  --password <value>       App-specific password (or APPLE_APP_SPECIFIC_PASSWORD env, avoid shell history)
  -h, --help               Show help

Example:
  APPLE_ID=<YOUR_APPLE_ID> APPLE_TEAM_ID=<YOUR_TEAM_ID> APPLE_APP_SPECIFIC_PASSWORD=<APP_SPECIFIC_PASSWORD> \
  scripts/setup_notary_profile.sh --profile CmdVNotary
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      PROFILE_NAME="$2"
      shift 2
      ;;
    --apple-id)
      APPLE_ID="$2"
      shift 2
      ;;
    --team-id)
      APPLE_TEAM_ID="$2"
      shift 2
      ;;
    --password)
      APPLE_APP_SPECIFIC_PASSWORD="$2"
      shift 2
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

if [[ -z "$APPLE_ID" || -z "$APPLE_TEAM_ID" || -z "$APPLE_APP_SPECIFIC_PASSWORD" ]]; then
  echo "Missing credentials. Provide APPLE_ID, APPLE_TEAM_ID, and APPLE_APP_SPECIFIC_PASSWORD." >&2
  exit 1
fi

xcrun notarytool store-credentials "$PROFILE_NAME" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD"

echo "Stored notary profile: $PROFILE_NAME"
