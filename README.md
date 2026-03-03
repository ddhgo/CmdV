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

#### 1) Install from release (recommended)

1. Download `CmdV-v*.zip` from [latest release](https://github.com/ddhgo/CmdV/releases/latest)
2. Unzip and move **CmdV.app** to your Applications folder
3. Launch CmdV from Applications

#### 2) Build from source

1. Clone this repository
2. Open `CmdV.xcodeproj` in Xcode
3. Select the `CmdV` target and run (`Cmd + R`)

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
- **Built-in capture hotkey** — capture a selected screen area directly to clipboard
- **Configurable** — language, launch at login, hotkeys, history capacity, polling interval, and more
- **No telemetry** — nothing leaves your Mac. Ever.

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Option + V` | Open / close clipboard history |
| `Control + Shift + Command + 4` | Capture screen to clipboard |

> All shortcuts are customizable in Settings.

### Permissions

**Accessibility** — Required for auto-paste. CmdV uses this to send `Cmd+V` after you select an item.
If you skip this, CmdV still copies the item to your clipboard — you just paste manually.

→ System Settings → Privacy & Security → Accessibility

### Privacy

- All data is stored locally on your Mac
- Stored at: `~/Library/Application Support/CmdV/`
- No network requests, no analytics, no tracking

### Troubleshooting

**"CmdV.app" cannot be opened because Apple cannot check it for malicious software**
This build is not notarized. Use one of the methods below:
- Finder: Right-click `CmdV.app` → **Open** → **Open**
- Terminal:
  `xattr -dr com.apple.quarantine /Applications/CmdV.app`

**Hotkey doesn't work**
Another app may be using the same shortcut. Change it in CmdV Settings → Keyboard Shortcuts.

**Item selected but not pasted automatically**
Grant Accessibility permission in System Settings → Privacy & Security → Accessibility.

**Clipboard entries not showing up**
Check that recording isn't paused (menu bar icon → Resume).

### Support

Found a bug or have a feature request?
→ [Open an issue](https://github.com/ddhgo/CmdV/issues/new/choose)

Like CmdV? Support development:
→ [Buy me a coffee](https://buymeacoffee.com/ddhgo)

---

## 한국어

### CmdV란?

CmdV는 복사한 모든 내용을 자동으로 기록하는 클립보드 관리 앱입니다. 텍스트, 이미지, 파일 가리지 않고 전부 저장해두고, 필요할 때 단축키 하나로 꺼내 쓸 수 있습니다.

### 설치

**요구 사항:** macOS 13.0 이상

#### 1) 릴리스 설치 (권장)

1. [최신 릴리스](https://github.com/ddhgo/CmdV/releases/latest)에서 `CmdV-v*.zip` 다운로드
2. 압축을 풀고 **CmdV.app**을 응용 프로그램 폴더로 이동
3. CmdV 실행

#### 2) 소스 빌드

1. 이 저장소를 클론
2. Xcode에서 `CmdV.xcodeproj` 열기
3. `CmdV` 타깃 선택 후 실행 (`Cmd + R`)

### 사용법

1. CmdV를 실행하면 메뉴바에 아이콘이 나타남
2. 처음 실행 시 **손쉬운 사용 권한**을 허용 *(자동 붙여넣기에 필요)*
3. `Option + V`로 클립보드 기록 창 열기
4. 검색하거나 항목을 선택한 뒤 `Enter`로 바로 붙여넣기

### 주요 기능

- **클립보드 기록** — 텍스트, 이미지, 파일을 복사할 때마다 자동 저장
- **즉시 검색** — 키워드를 입력하면 바로 필터링
- **고정** — 자주 쓰는 항목을 목록 맨 위에 고정
- **즐겨찾기** — 중요한 항목을 별도 탭에서 모아보기
- **화면 캡처 단축키** — 선택 영역을 캡처해서 클립보드에 바로 저장
- **세부 설정** — 언어, 로그인 시 자동 실행, 단축키, 저장 개수, 폴링 주기 등
- **완전 로컬** — 데이터가 외부로 전송되지 않음

### 단축키

| 키 | 동작 |
|----|------|
| `Option + V` | 클립보드 기록 창 열기 / 닫기 |
| `Control + Shift + Command + 4` | 화면 캡처 후 클립보드에 저장 |

> 모든 단축키는 설정에서 변경할 수 있습니다.

### 권한

**손쉬운 사용 (Accessibility)** — 자동 붙여넣기에 필요합니다. 항목을 선택하면 `Cmd+V`를 자동으로 눌러주는 데 쓰입니다.
권한을 허용하지 않아도 항목은 클립보드에 복사되며, 직접 `Cmd+V`로 붙여넣으면 됩니다.

→ 시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용

### 개인정보

- 모든 데이터는 이 Mac에만 저장됩니다
- 저장 위치: `~/Library/Application Support/CmdV/`
- 네트워크 요청, 분석, 추적 일체 없음

### 문제 해결

**"CmdV.app"을(를) 열 수 없다는 경고가 떠요**
공증(notarization)되지 않은 빌드이기 때문입니다. 아래 방법 중 하나로 실행하세요:
- Finder에서 `CmdV.app` 우클릭 → **열기** → **열기**
- 터미널에서 실행:
  `xattr -dr com.apple.quarantine /Applications/CmdV.app`

**단축키가 안 돼요**
다른 앱이 같은 단축키를 쓰고 있을 수 있습니다. 설정 → 단축키에서 변경해보세요.

**항목을 선택했는데 자동 붙여넣기가 안 돼요**
시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용에서 CmdV를 허용해주세요.

**복사한 내용이 목록에 안 나와요**
기록이 일시정지 상태인지 확인하세요. 메뉴바 아이콘을 클릭해서 활성화할 수 있습니다.

### 지원

버그 제보나 기능 제안은 여기로:
→ [이슈 등록](https://github.com/ddhgo/CmdV/issues/new/choose)

CmdV가 마음에 드셨다면:
→ [커피 한 잔 사주기](https://buymeacoffee.com/ddhgo)

---

<sub>Made by [ddhgo](https://github.com/ddhgo)</sub>
