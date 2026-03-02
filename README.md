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

1. Download `CmdV.dmg` from [latest release](https://github.com/ddhgo/CmdV/releases/latest)
2. Open the DMG and drag **CmdV** to your Applications folder
3. Launch CmdV from Applications

#### 2) Build from source

1. Clone this repository
2. Open `CmdV.xcodeproj` in Xcode
3. Select the `CmdV` target and run (`Cmd + R`)

### Usage

1. Launch CmdV — it appears in the menu bar (⌘✓)
2. Grant **Accessibility permission** when prompted *(required for auto-paste)*
3. Press `Option + V` to open clipboard history
4. Search, select an item, and press `Enter` to paste

### Features

- **Clipboard history** — automatically captures text, images, and files as you copy
- **Instant search** — type to filter through your history
- **Pin items** — keep important clips at the top of your history list
- **Favorites tab** — keep starred items in a separate tab
- **Built-in capture hotkey** — capture a selected screen area directly to clipboard
- **Fully keyboard-driven** — open, search, select, and paste without touching the mouse
- **Privacy controls** — pause recording, clear history, and optionally clear history on restart
- **Configurable** — language, launch at login, hotkeys, history capacity, polling interval, and more
- **No telemetry** — nothing leaves your Mac. Ever.

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Option + V` | Open / close clipboard history |
| `Control + Shift + Command + 4` | Default clipboard capture shortcut |

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

### CmdV가 뭔가요?

CmdV는 메뉴바에 상주하며 복사한 모든 것 — 텍스트, 이미지, 파일 — 을 자동으로 기록합니다. 이전에 복사했던 내용이 필요할 때 단축키 하나로 목록을 열어 바로 붙여넣을 수 있어요.

두 번 복사하느라 낭비하는 시간, 이제 없어도 됩니다.

### 설치

**요구 사항:** macOS 13.0 이상

#### 1) 릴리스로 설치 (권장)

1. [최신 릴리스](https://github.com/ddhgo/CmdV/releases/latest)에서 `CmdV.dmg` 다운로드
2. DMG를 열고 **CmdV**를 Applications 폴더로 드래그
3. Applications에서 CmdV 실행

#### 2) 소스에서 빌드

1. 이 저장소를 클론
2. Xcode에서 `CmdV.xcodeproj` 열기
3. `CmdV` 타깃 선택 후 실행 (`Cmd + R`)

### 사용법

1. CmdV 실행 — 메뉴바에 아이콘이 나타납니다 (⌘✓)
2. 요청 시 **손쉬운 사용(Accessibility) 권한** 허용 *(자동 붙여넣기에 필요)*
3. `Option + V`를 눌러 클립보드 히스토리 열기
4. 검색 후 항목을 선택하고 `Enter`로 붙여넣기

### 주요 기능

- **클립보드 히스토리** — 복사할 때마다 텍스트, 이미지, 파일을 자동으로 기록
- **빠른 검색** — 입력하면 바로 필터링
- **핀 고정** — 중요한 항목을 히스토리 목록 상단에 고정
- **즐겨찾기 탭** — 별표한 항목을 별도 탭에서 관리
- **기본 캡처 단축키 제공** — 선택 영역을 캡처해 클립보드에 바로 복사
- **완전한 키보드 조작** — 마우스 없이 열고, 검색하고, 붙여넣기까지
- **프라이버시 제어** — 기록 일시정지, 히스토리 삭제, 재시동 시 기록 삭제 옵션
- **세부 설정** — 언어, 로그인 시 실행, 단축키, 히스토리 용량, 폴링 주기 등 변경 가능
- **완전한 로컬 저장** — 어떤 데이터도 외부로 나가지 않습니다

### 단축키

| 키 | 동작 |
|----|------|
| `Option + V` | 클립보드 히스토리 열기 / 닫기 |
| `Control + Shift + Command + 4` | 기본 클립보드 캡처 단축키 |

> 모든 단축키는 설정에서 변경할 수 있습니다.

### 권한 안내

**손쉬운 사용 (Accessibility)** — 자동 붙여넣기에 필요합니다. 항목 선택 후 `Cmd+V`를 자동으로 입력하는 데 사용됩니다.
권한을 허용하지 않아도 클립보드에 복사는 되며, 수동으로 붙여넣기(`Cmd+V`)하면 됩니다.

→ 시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용

### 개인정보 보호

- 모든 데이터는 내 Mac에만 저장됩니다
- 저장 위치: `~/Library/Application Support/CmdV/`
- 네트워크 요청, 분석, 추적 없음

### 문제 해결

**단축키가 작동하지 않아요**
다른 앱이 동일한 단축키를 사용 중일 수 있습니다. CmdV 설정 → 단축키에서 변경해보세요.

**항목을 선택했는데 자동으로 붙여넣기가 안 돼요**
시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용에서 CmdV에 권한을 허용해주세요.

**복사한 항목이 목록에 안 나타나요**
기록이 일시정지 상태인지 확인해보세요 (메뉴바 아이콘 → 재개).

### 지원

버그 제보 또는 기능 제안:
→ [이슈 등록](https://github.com/ddhgo/CmdV/issues/new/choose)

CmdV가 유용하셨나요? 개발을 응원해주세요:
→ [커피 한 잔 사주기](https://buymeacoffee.com/ddhgo)

---

<sub>Made by [ddhgo](https://github.com/ddhgo)</sub>
