#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DRY_RUN=0

usage() {
  cat <<'USAGE'
Usage: scripts/clean_build_artifacts.sh [--dry-run]

Removes local build artifacts that often cause stale CmdV binaries to coexist.

Options:
  --dry-run   Show what would be removed without deleting
  -h, --help  Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
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

remove_path() {
  local path="$1"
  if [[ -e "$path" ]]; then
    if [[ "$DRY_RUN" -eq 1 ]]; then
      echo "DRY-RUN remove: $path"
    else
      rm -rf "$path"
      echo "Removed: $path"
    fi
  fi
}

remove_glob() {
  local pattern="$1"
  local matches=()
  shopt -s nullglob
  matches=($pattern)
  shopt -u nullglob

  if [[ ${#matches[@]} -eq 0 ]]; then
    return
  fi

  local match
  for match in "${matches[@]}"; do
    remove_path "$match"
  done
}

echo "Cleaning CmdV build artifacts under: $ROOT_DIR"

remove_path "$ROOT_DIR/build/Build"
remove_path "$ROOT_DIR/build/DerivedData"
remove_path "$ROOT_DIR/build/ReleaseDerivedData"
remove_path "$ROOT_DIR/build/archive"
remove_path "$ROOT_DIR/dist/release"
remove_path "$ROOT_DIR/output/distribution/CmdV.app"

remove_glob "$ROOT_DIR/dist/CmdV-"*.dmg
remove_glob "$ROOT_DIR/output/distribution/CmdV_"*.zip

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry run complete."
else
  echo "Cleanup complete."
fi
