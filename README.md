# CmdV

<p align="center">
  <img src="CmdV/Resources/CmdVMainLogo.png" alt="CmdV Logo" width="180" />
</p>

**macOS clipboard history manager — inspired by Windows Win+V.**
Copy anything. Come back to it anytime.

[English](#english) · [한국어](#한국어)

---

## English

### What is CmdV?

CmdV lives in your menu bar and silently keeps a history of everything you copy — text, images, and files. Whenever you need something you copied earlier, just press a hotkey and pick it from the list.

No more losing that thing you copied two pastes ago.

### Installation

**Requirements:** macOS 13.0 or later

If you do not have Homebrew installed yet, install it first from the official Homebrew site:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then reopen Terminal and confirm Homebrew is available:

```bash
brew --version
```

Official Homebrew install guide: [brew.sh](https://brew.sh/)

#### 1) Homebrew (recommended)

```bash
brew tap ddhgo/cmdv
brew install --cask cmdv
```

Update an existing Homebrew installation:

```bash
brew update
brew upgrade --cask cmdv
```

#### 2) Install from release

1. Download `CmdV-v*.zip` from [latest release](https://github.com/ddhgo/CmdV/releases/latest)
2. Unzip and move **CmdV.app** to your Applications folder
3. Launch CmdV from Applications

> **Note:** This build is not notarized. macOS may block the first launch — see [Troubleshooting](#troubleshooting) below.

#### 3) Build from source

1. Clone this repository
2. Open `CmdV.xcodeproj` in Xcode
3. Select the `CmdV` target and run (`Cmd + R`)

### Uninstall / Complete removal

If you installed CmdV with Homebrew and want to remove it completely:

```bash
brew uninstall --cask cmdv
brew untap ddhgo/cmdv
rm -rf ~/Library/Application\ Support/CmdV
rm -f ~/Library/Preferences/com.cmdv.app.plist
```

Optional cleanup:
- If **Launch at Login** was enabled, remove CmdV from System Settings → General → Login Items if it is still listed.
- If you granted **Accessibility** permission, remove CmdV from System Settings → Privacy & Security → Accessibility.

### Usage

1. Launch CmdV — it appears in the menu bar
2. Grant **Accessibility permission** when prompted *(required for auto-paste)*
3. Press `Option + V` to open clipboard history
4. Search, select an item, and press `Enter` to paste

### Features

- **Clipboard history** — automatically captures text, images, and files as you copy
- **Instant search** — type to filter through your history
- **Pin items** — keep important clips at the top of your history list
- **Favorites tab** — star items and manage them in a separate tab
- **Clipboard capture hotkey** — capture a selected screen area directly to clipboard
- **Configurable** — language, launch at login, hotkeys, history capacity, polling interval, and more
- **No telemetry** — nothing leaves your Mac. Ever.

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Option + V` | Open / close clipboard history |
| `Option + Shift + S` | Clipboard capture |

> All shortcuts are customizable in Settings.

### Permissions

**Accessibility** — Required for auto-paste.

> **What is auto-paste?** When you select an item from clipboard history, CmdV copies it to your clipboard *and* automatically pastes it into the active app by simulating `Cmd+V`. Without this permission, CmdV still copies the item — you just press `Cmd+V` yourself.

→ System Settings → Privacy & Security → Accessibility

### Privacy

- All data is stored locally on your Mac
- Stored at: `~/Library/Application Support/CmdV/`
- No network requests, no analytics, no tracking

### Troubleshooting

#### "CmdV.app" cannot be opened because Apple cannot check it for malicious software

This build is not notarized. Use one of the methods below:

- Finder: Right-click `CmdV.app` → **Open** → **Open**
- Terminal:
  `xattr -dr com.apple.quarantine /Applications/CmdV.app`

#### Hotkey doesn't work

Another app may be using the same shortcut. Change it in CmdV Settings → Keyboard Shortcuts.

#### Item selected but not pasted automatically

Grant Accessibility permission in System Settings → Privacy & Security → Accessibility.

#### Accessibility is enabled, but CmdV still says the permission is missing

- Remove CmdV from System Settings → Privacy & Security → Accessibility
- Replace the app with the latest release build, then add CmdV again
- If you installed with Homebrew, run `brew update && brew upgrade --cask cmdv`

macOS ties Accessibility approval to the exact signed app bundle, so replacing an older build can require re-adding permission once.

#### Clipboard entries not showing up

Check that recording isn't paused (menu bar icon → Resume).

### Support

Found a bug or have a feature request?
→ [Open an issue](https://github.com/ddhgo/CmdV/issues/new/choose)

Like CmdV? Support development:
→ [Buy me a coffee](https://buymeacoffee.com/ddhgo)

### Maintainer Release Flow

After bumping the app version and committing the release changes, run:

```bash
scripts/publish_release.sh
```

This packages the release, pushes the current branch and `v<version>` tag, creates or updates the GitHub release, and syncs the Homebrew cask in `ddhgo/homebrew-cmdv`.

If you already have fresh release artifacts, reuse them with:

```bash
scripts/publish_release.sh --skip-build
```

---

## 한국어

### CmdV란?

CmdV는 복사한 모든 내용을 자동으로 기록하는 클립보드 관리 앱입니다. 텍스트, 이미지, 파일 가리지 않고 전부 저장해두고, 필요할 때 단축키 하나로 꺼내 쓸 수 있습니다.

### 설치

**요구 사항:** macOS 13.0 이상

Homebrew가 아직 설치되어 있지 않다면 먼저 공식 안내대로 설치하세요:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

설치 후에는 터미널을 다시 열고 아래로 정상 설치 여부를 확인하세요:

```bash
brew --version
```

공식 Homebrew 설치 안내: [brew.sh](https://brew.sh/)

#### 1) Homebrew (권장)

```bash
brew tap ddhgo/cmdv
brew install --cask cmdv
```

기존 Homebrew 설치를 업데이트하려면:

```bash
brew update
brew upgrade --cask cmdv
```

#### 2) 릴리스 설치

1. [최신 릴리스](https://github.com/ddhgo/CmdV/releases/latest)에서 `CmdV-v*.zip` 다운로드
2. 압축을 풀고 **CmdV.app**을 응용 프로그램 폴더로 이동
3. CmdV 실행

> **참고:** 이 빌드는 공증(notarization)되지 않아 macOS가 첫 실행을 차단할 수 있습니다. 아래 [문제 해결](#문제-해결) 항목을 참고하세요.

#### 3) 소스 빌드

1. 이 저장소를 클론
2. Xcode에서 `CmdV.xcodeproj` 열기
3. `CmdV` 타깃 선택 후 실행 (`Cmd + R`)

### 삭제 / 완전 제거

Homebrew로 설치한 CmdV를 완전히 지우려면 아래 순서대로 실행하세요.

```bash
brew uninstall --cask cmdv
brew untap ddhgo/cmdv
rm -rf ~/Library/Application\ Support/CmdV
rm -f ~/Library/Preferences/com.cmdv.app.plist
```

추가 정리:
- **로그인 시 자동 실행**을 켜둔 경우, 시스템 설정 → 일반 → 로그인 항목에서 CmdV가 남아 있으면 제거하세요.
- **손쉬운 사용 권한**을 허용한 경우, 시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용에서 CmdV를 제거하세요.

### 사용법

1. CmdV를 실행하면 메뉴바에 아이콘이 나타남
2. 처음 실행 시 **손쉬운 사용 권한**을 허용 *(자동 붙여넣기에 필요)*
3. `Option + V`로 클립보드 기록 창 열기
4. 원하는 항목을 선택하면 바로 붙여넣기됨

### 주요 기능

- **클립보드 기록** — 텍스트, 이미지, 파일을 복사할 때마다 자동 저장
- **즉시 검색** — 키워드를 입력하면 바로 필터링
- **고정** — 자주 쓰는 항목을 목록 맨 위에 고정
- **즐겨찾기** — 중요한 항목을 별도 탭에서 모아보기
- **클립보드 캡처** — 선택 영역을 캡처해서 클립보드에 바로 저장
- **세부 설정** — 언어, 로그인 시 자동 실행, 단축키, 저장 개수, 폴링 주기 등
- **완전 로컬** — 데이터가 외부로 전송되지 않음

### 단축키

| 키 | 동작 |
|----|------|
| `Option + V` | 클립보드 기록 창 열기 / 닫기 |
| `Option + Shift + S` | 클립보드 캡처 |

> 모든 단축키는 설정에서 변경할 수 있습니다.

### 권한

**손쉬운 사용 (Accessibility)** — 자동 붙여넣기에 필요합니다.

> **자동 붙여넣기란?** 클립보드 기록에서 항목을 선택하면, CmdV가 해당 내용을 클립보드에 복사하고 활성 앱에 `Cmd+V`를 자동으로 입력해줍니다. 권한이 없어도 클립보드 복사는 되며, 직접 `Cmd+V`를 누르면 됩니다.

→ 시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용

### 개인정보

- 모든 데이터는 이 Mac에만 저장됩니다
- 저장 위치: `~/Library/Application Support/CmdV/`
- 네트워크 요청, 분석, 추적 일체 없음

### 문제 해결

#### "CmdV.app"을(를) 열 수 없다는 경고가 떠요

공증(notarization)되지 않은 빌드라 macOS에서 첫 실행을 막을 수 있습니다.
아래 방법 중 하나로 실행해 주세요.

- Finder에서 `CmdV.app` 우클릭 → **열기** → **열기**
- 터미널에서 실행:
  `xattr -dr com.apple.quarantine /Applications/CmdV.app`

#### 단축키가 안 돼요

다른 앱이 같은 단축키를 사용 중일 수 있습니다.
CmdV 설정 → 단축키에서 다른 조합으로 바꿔보세요.

#### 항목을 선택했는데 자동 붙여넣기가 안 돼요

자동 붙여넣기를 사용하려면 손쉬운 사용 권한이 필요합니다.
시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용에서 CmdV를 허용해 주세요.

#### 손쉬운 사용이 켜져 있는데도 CmdV가 권한이 없다고 나와요

- 시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용에서 CmdV를 삭제
- 최신 릴리스 빌드로 앱을 교체한 뒤 CmdV를 다시 추가
- Homebrew 설치였다면 `brew update && brew upgrade --cask cmdv` 실행

macOS는 손쉬운 사용 권한을 "현재 설치된 서명된 앱 번들" 기준으로 저장합니다.
그래서 이전 빌드를 교체한 뒤에는 권한을 한 번 더 추가해야 할 수 있습니다.

#### 복사한 내용이 목록에 안 나와요

기록이 일시정지 상태인지 먼저 확인해 주세요.
메뉴바 아이콘을 클릭하면 다시 활성화할 수 있습니다.

### 지원

버그 제보나 기능 제안은 여기로:
→ [이슈 등록](https://github.com/ddhgo/CmdV/issues/new/choose)

CmdV가 마음에 드셨다면:
→ [커피 한 잔 사주기](https://buymeacoffee.com/ddhgo)

### 유지보수용 릴리스 배포

앱 버전을 올리고 릴리스 변경사항을 커밋한 뒤 아래 명령을 실행하세요.

```bash
scripts/publish_release.sh
```

이 스크립트는 릴리스 패키징, 현재 브랜치와 `v<version>` 태그 푸시, GitHub 릴리스 생성 또는 갱신, `ddhgo/homebrew-cmdv` Homebrew cask 동기화까지 한 번에 처리합니다.

이미 최신 릴리스 아티팩트를 만들어둔 상태라면 아래처럼 재사용할 수 있습니다.

```bash
scripts/publish_release.sh --skip-build
```

---

<sub>Made by [ddhgo](https://github.com/ddhgo)</sub>
