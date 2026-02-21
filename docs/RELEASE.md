# CmdV Release Guide

This guide describes the standard release flow for a signed and notarized DMG.

## Distribution Policy (Beta/Production)

- Default distribution format: **Release DMG**
- Recommended: **Developer ID signed + notarized DMG**
- ZIP builds are for internal ad-hoc sharing only and are not recommended for tester distribution
  because Gatekeeper and Accessibility trust can be less predictable.

## 1) Prerequisites

- Apple Developer membership (Developer ID distribution)
- Developer ID Application certificate installed in login keychain
- App-specific password for your Apple ID (for notarization), or a saved notarytool keychain profile

## 2) Environment Variables

Required for signing:

- `APPLE_TEAM_ID` (example: `ABCDE12345`)
- `APP_SIGN_IDENTITY` (example: `Developer ID Application: Your Name (ABCDE12345)`)

Notarization options:

- Preferred: `NOTARY_PROFILE` (keychain profile name)
- Or:
  - `APPLE_ID`
  - `APPLE_APP_SPECIFIC_PASSWORD`

## 3) One-Time Notary Profile Setup (Recommended)

```bash
APPLE_ID="<YOUR_APPLE_ID>" \
APPLE_TEAM_ID="<YOUR_TEAM_ID>" \
APPLE_APP_SPECIFIC_PASSWORD="<APP_SPECIFIC_PASSWORD>" \
scripts/setup_notary_profile.sh --profile CmdVNotary
```

## 4) Build Signed + Notarized DMG

```bash
APPLE_TEAM_ID="ABCDE12345" \
APP_SIGN_IDENTITY="Developer ID Application: Your Name (ABCDE12345)" \
NOTARY_PROFILE="CmdVNotary" \
scripts/release_signed_notarized_dmg.sh
```

Credential safety:
- Prefer `NOTARY_PROFILE` and avoid entering passwords directly in terminal commands.
- Keep real credentials in Keychain/GitHub Secrets only.

Output:

- `dist/release/CmdV-<version>.dmg`

## 5) Useful Flags

- Skip archive and reuse existing archive:

```bash
scripts/release_signed_notarized_dmg.sh --skip-archive
```

- Create signed DMG but skip notarization:

```bash
scripts/release_signed_notarized_dmg.sh --skip-notarize
```

## 6) Troubleshooting

- `No identity found`:
  - Verify certificate in Keychain Access and exact `APP_SIGN_IDENTITY` string.
- Notarization auth failure:
  - Verify app-specific password and team id, or refresh notary profile.
- Stapling failure:
  - Ensure notarization finished successfully and rerun stapling.

## 7) GitHub Actions Release

Workflow file:

- `.github/workflows/release.yml`

Required repository secrets:

- `APPLE_TEAM_ID`
- `APP_SIGN_IDENTITY`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `DEVELOPER_ID_APPLICATION_P12_BASE64`
- `DEVELOPER_ID_APPLICATION_P12_PASSWORD`
- `KEYCHAIN_PASSWORD`
