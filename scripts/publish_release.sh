#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: scripts/publish_release.sh [--skip-build] [--skip-homebrew] [--dry-run]

Packages the CmdV release build, pushes the current branch and version tag,
creates or updates the GitHub release, and syncs the Homebrew cask tap.

Options:
  --skip-build      Reuse the existing Release build and artifacts.
  --skip-homebrew   Skip syncing the Homebrew tap.
  --dry-run         Print the publish commands without changing remotes.
  -h, --help        Show this help message.

Environment:
  CMDV_SIGN_IDENTITY       Passed through to scripts/package_release.sh.
  CMDV_HOMEBREW_TAP_REPO   Homebrew tap repo. Default: ddhgo/homebrew-cmdv
  CMDV_HOMEBREW_CASK_PATH  Cask path inside the tap. Default: Casks/cmdv.rb
  DEVELOPER_DIR            Xcode developer directory used for packaging.
EOF
}

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skip_build=0
skip_homebrew=0
dry_run=0
declare -a temp_dirs=()

cleanup() {
  local dir
  for dir in "${temp_dirs[@]:-}"; do
    if [[ -n "$dir" && -d "$dir" ]]; then
      rm -rf "$dir"
    fi
  done
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      skip_build=1
      shift
      ;;
    --skip-homebrew)
      skip_homebrew=1
      shift
      ;;
    --dry-run)
      dry_run=1
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

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Required command not found: $1" >&2
    exit 1
  fi
}

run_cmd() {
  if [[ "$dry_run" -eq 1 ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi

  "$@"
}

ensure_git_identity() {
  local repo_dir="$1"
  local login

  if git -C "$repo_dir" config user.name >/dev/null 2>&1 && \
     git -C "$repo_dir" config user.email >/dev/null 2>&1; then
    return
  fi

  login="$(gh api user --jq .login)"
  git -C "$repo_dir" config user.name "${GIT_AUTHOR_NAME:-$login}"
  git -C "$repo_dir" config user.email "${GIT_AUTHOR_EMAIL:-$login@users.noreply.github.com}"
}

update_homebrew_tap() {
  local version="$1"
  local sha256="$2"
  local tap_repo="${CMDV_HOMEBREW_TAP_REPO:-ddhgo/homebrew-cmdv}"
  local cask_path="${CMDV_HOMEBREW_CASK_PATH:-Casks/cmdv.rb}"
  local tap_root
  local tap_dir
  local cask_file
  local tap_branch

  tap_root="$(mktemp -d "$root_dir/build/homebrew-tap.XXXXXX")"
  temp_dirs+=("$tap_root")
  tap_dir="$tap_root/repo"

  gh repo clone "$tap_repo" "$tap_dir" -- --quiet

  cask_file="$tap_dir/$cask_path"
  if [[ ! -f "$cask_file" ]]; then
    echo "Homebrew cask file not found: $cask_path" >&2
    exit 1
  fi

  ruby - "$cask_file" "$version" "$sha256" <<'RUBY'
file_path, version, sha256 = ARGV
content = File.read(file_path)

unless content.sub!(/version\s+"[^"]+"/, %(version "#{version}"))
  abort("Could not find a version entry in #{file_path}")
end

unless content.sub!(/sha256\s+"[^"]+"/, %(sha256 "#{sha256}"))
  abort("Could not find a sha256 entry in #{file_path}")
end

File.write(file_path, content)
RUBY

  if git -C "$tap_dir" diff --quiet -- "$cask_path"; then
    echo "Homebrew tap already points to CmdV v$version"
    return
  fi

  ensure_git_identity "$tap_dir"
  tap_branch="$(git -C "$tap_dir" branch --show-current)"

  run_cmd git -C "$tap_dir" add "$cask_path"
  run_cmd git -C "$tap_dir" commit -m "cmdv $version"
  run_cmd git -C "$tap_dir" push origin "$tap_branch"
}

require_command git
require_command gh
require_command ruby

if [[ ! -x /usr/libexec/PlistBuddy ]]; then
  echo "Required tool not found: /usr/libexec/PlistBuddy" >&2
  exit 1
fi

if [[ -n "$(git -C "$root_dir" status --short --untracked-files=no)" ]]; then
  if [[ "$dry_run" -eq 1 ]]; then
    echo "[dry-run] Tracked changes detected. A real publish would stop until they are committed or stashed."
  else
    echo "Tracked changes detected. Commit or stash them before publishing a release." >&2
    exit 1
  fi
fi

package_args=()
if [[ "$skip_build" -eq 1 ]]; then
  package_args+=(--skip-build)
fi

if [[ "$dry_run" -eq 1 ]]; then
  echo "[dry-run] Skipping package build. Reusing existing release artifacts."
else
  if [[ "${#package_args[@]}" -gt 0 ]]; then
    "$root_dir/scripts/package_release.sh" "${package_args[@]}"
  else
    "$root_dir/scripts/package_release.sh"
  fi
fi

app_path="$root_dir/build/codex-release/Build/Products/Release/CmdV.app"
plist_path="$app_path/Contents/Info.plist"

if [[ ! -f "$plist_path" ]]; then
  echo "Release Info.plist not found at $plist_path" >&2
  echo "Build the release once first, or rerun without --dry-run/with --skip-build as appropriate." >&2
  exit 1
fi

marketing_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist_path")"
build_number="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$plist_path")"
tag="v$marketing_version"
release_title="CmdV $tag"
artifact_dir="$root_dir/build/release-artifacts/$tag"
zip_path="$artifact_dir/CmdV-$tag.zip"
checksum_path="$zip_path.sha256"

if [[ ! -f "$zip_path" || ! -f "$checksum_path" ]]; then
  echo "Release artifacts not found for $tag in $artifact_dir" >&2
  echo "Run scripts/package_release.sh first, or rerun without --dry-run." >&2
  exit 1
fi

sha256="$(awk '{print $1}' "$checksum_path")"
branch="$(git -C "$root_dir" branch --show-current)"

if [[ -z "$branch" ]]; then
  echo "Publishing a release requires checking out a named branch." >&2
  exit 1
fi

head_commit="$(git -C "$root_dir" rev-parse HEAD)"
if git -C "$root_dir" rev-parse "$tag" >/dev/null 2>&1; then
  tag_commit="$(git -C "$root_dir" rev-list -n 1 "$tag")"
  if [[ "$tag_commit" != "$head_commit" ]]; then
    echo "Tag $tag already exists on a different commit. Move or delete it manually before retrying." >&2
    exit 1
  fi
else
  run_cmd git -C "$root_dir" tag -a "$tag" -m "$release_title"
fi

run_cmd git -C "$root_dir" push origin "$branch"
run_cmd git -C "$root_dir" push origin "$tag"

if gh release view "$tag" >/dev/null 2>&1; then
  run_cmd gh release upload "$tag" "$zip_path" "$checksum_path" --clobber
  run_cmd gh release edit "$tag" --title "$release_title"
else
  run_cmd gh release create "$tag" "$zip_path" "$checksum_path" --title "$release_title" --generate-notes
fi

if [[ "$skip_homebrew" -eq 0 ]]; then
  update_homebrew_tap "$marketing_version" "$sha256"
else
  echo "Skipping Homebrew tap sync."
fi

echo "Published CmdV v$marketing_version ($build_number)"
echo "Release: https://github.com/ddhgo/CmdV/releases/tag/$tag"
if [[ "$skip_homebrew" -eq 0 ]]; then
  echo "Homebrew tap: ${CMDV_HOMEBREW_TAP_REPO:-ddhgo/homebrew-cmdv}"
fi
