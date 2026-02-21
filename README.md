# CmdV

CmdV is a production-focused macOS clipboard history app inspired by Windows Win+V.

It runs as a menu bar app, captures text and images, and lets you quickly re-paste previous clipboard entries with a global hotkey.

## MVP Features

- Menu bar app with status icon and controls.
- Global hotkey (default `Option+V`) to toggle popup.
- Clipboard history for:
  - Plain text (`public.utf8-plain-text` via `.string`)
  - Images (`.png` / `.tiff` converted and stored as PNG)
- Search/filter in popup.
- Pin/favorite important items so they stay at top.
- Keyboard controls:
  - Up/Down: selection
  - Enter: paste selected item
  - Cmd+Enter: copy selected item only (no auto-paste)
  - Cmd+P: pin/unpin selected item
  - Esc: close popup
  - Cmd+F: focus search
  - Delete/Backspace: delete selected history item
- Privacy controls:
  - Pause recording
  - Clear history
  - Excluded app bundle identifiers (settings)
- Persistence:
  - SQLite metadata database
  - Image files stored by content hash under Application Support
- Capacity limit (default 200, configurable).

## Architecture

- UI: SwiftUI + AppKit bridge (status bar, floating panel, global hotkey).
- Clipboard monitor: `NSPasteboard.general.changeCount` polling.
- Persistence: native SQLite (`SQLite3`) + hashed image files on disk.
- Global hotkey: Carbon `RegisterEventHotKey`.
- Auto-paste: sets selected content to pasteboard, then sends Cmd+V via `CGEvent`.

## Build and Run (Xcode)

1. Open `CmdV.xcodeproj` in Xcode.
2. Select the `CmdV` target.
3. Build and run (`Cmd+R`).

Notes:
- The project targets macOS 13.0+.
- MVP is intentionally non-sandboxed to keep global hotkey and auto-paste behavior reliable.

## Automated Tests

- Unit tests target: `CmdVTests` (XCTest)
- Run in Xcode: Product -> Test
- Run in terminal:

```bash
xcodebuild -project "CmdV.xcodeproj" -scheme "CmdV" -configuration Debug -destination 'platform=macOS' test
```

Current coverage focus:
- `SettingsStore` clamping/parsing/hotkey fallback logic
- `SQLiteHistoryDatabase` insert/fetch/trim/clear behavior

CI workflow:
- `.github/workflows/ci.yml` (build + test on macOS)

## Packaging (DMG)

Create a distributable DMG with:

```bash
./scripts/create_dmg.sh
```

Useful options:

```bash
./scripts/create_dmg.sh --configuration Debug --derived-data build/DerivedData --output dist
./scripts/create_dmg.sh --skip-build --configuration Release --derived-data build/DerivedData --output dist
```

Default output:
- `dist/CmdV-<version>.dmg`

Distribution note:
- Share **Release DMG** for external testers.
- ZIP sharing is intended only for internal quick checks.

## Signed Release (Developer ID + Notarization)

Production release flow script:

```bash
APPLE_TEAM_ID="ABCDE12345" \
APP_SIGN_IDENTITY="Developer ID Application: Your Name (ABCDE12345)" \
NOTARY_PROFILE="CmdVNotary" \
scripts/release_signed_notarized_dmg.sh
```

Notary profile one-time setup:

```bash
APPLE_ID="<YOUR_APPLE_ID>" \
APPLE_TEAM_ID="<YOUR_TEAM_ID>" \
APPLE_APP_SPECIFIC_PASSWORD="<APP_SPECIFIC_PASSWORD>" \
scripts/setup_notary_profile.sh --profile CmdVNotary
```

Security note:
- Do not paste real credentials directly into shell history.
- Prefer `NOTARY_PROFILE` after one-time keychain setup.

Release docs:
- `docs/RELEASE.md`

GitHub Actions release workflow:
- `.github/workflows/release.yml`

## Permissions

### Accessibility (required for auto-paste)

CmdV needs Accessibility permission to synthesize `Cmd+V` after you choose an item.

If permission is missing:
- CmdV still copies the selected item to clipboard.
- You can manually paste with `Cmd+V`.
- The popup shows guidance and buttons to request/open settings.

Path in System Settings:
- Privacy & Security -> Accessibility

### Input Monitoring

Current implementation only sends events and does not read raw keyboard input globally.
Accessibility is the primary required permission for auto-paste.

## Data Storage

Stored under:
- `~/Library/Application Support/CmdV/history.sqlite3`
- `~/Library/Application Support/CmdV/Images/*.png`

No telemetry, no analytics, and no network calls are included.

## Troubleshooting

- Hotkey does not trigger:
  - Check if another app already owns the same shortcut.
  - Change the hotkey in CmdV Settings.
- Item selected but not auto-pasted:
  - Grant Accessibility permission.
  - Confirm CmdV is enabled under Accessibility.
- Clipboard entries not appearing:
  - Ensure recording is not paused.
  - Check exclusion list in Settings.

## v1.1 Roadmap

- Pin/favorite items.
- More robust rich text/HTML handling.
- Optional iCloud sync.
- Better item actions (copy only, preview pane, quick pin).

## QA

- Manual acceptance and edge-case checklist: `docs/QA_CHECKLIST.md`
