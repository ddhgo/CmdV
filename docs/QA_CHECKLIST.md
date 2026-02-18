# CmdV QA Checklist

## Acceptance Criteria Validation

1. Text capture within 1s
   - Copy text in Notes, Safari, or Terminal.
   - Open popup (`Option+V`).
   - Verify copied text appears at top.

2. Image capture with thumbnail
   - Copy an image (e.g., screenshot from Finder preview).
   - Open popup and verify image row with thumbnail.

3. Popup open/close
   - Press `Option+V` to open.
   - Press `Esc` to close.

4. Keyboard selection and paste
   - Open popup while another app is active.
   - Use Up/Down to select an item.
   - Press Enter.
   - Verify focus returns to prior app and selected content is pasted.

5. Search filtering
   - Open popup.
   - Type in search field.
   - Verify list filters immediately.

6. Persistence after restart
   - Quit CmdV.
   - Relaunch app.
   - Verify previous history remains.

7. Clear history
   - Click Clear in popup or menu.
   - Verify list becomes empty.

8. Missing Accessibility permission fallback
   - Disable CmdV in Accessibility settings.
   - Select an item in popup.
   - Verify item is copied to clipboard but auto-paste does not fire.
   - Verify guidance banner is visible in popup.

## Edge Cases

- Rapid copy bursts (20+ copies quickly).
- Large image copy (>10MB PNG/TIFF).
- Switching active app while popup is open.
- Exclusion rules: add bundle id and verify no capture from excluded app.
- Pause recording enabled: verify no new entries are captured.
- De-dup check: copy same content twice consecutively and verify only one entry.

## Automated Unit Tests

Run:

```bash
xcodebuild -project "CmdV.xcodeproj" -scheme "CmdV" -configuration Debug -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```
