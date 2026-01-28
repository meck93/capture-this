# Development Guide

## Tooling

- Install dependencies with `mise install`.
- Generate the Xcode project with `mise run generate`.

## Build & Test

```bash
mise run lint
mise run build
mise run test
```

## Run the App Manually

1. Build the Debug app:

```bash
mise run build
```

2. Launch the app bundle:

```bash
open .build/Build/Products/Debug/CaptureThis.app
```

3. The app appears in the menu bar (no Dock icon).

## Manual Test Checklist

### Permissions

- Toggle **Camera** on and start recording. Verify the system camera permission prompt appears.
- Toggle **Microphone** on and start recording. Verify the system microphone permission prompt appears.
- Deny one permission and confirm the app shows an error in the popover.

### Recording Flow

- Click **Record** → ensure the countdown appears and the picker is shown.
- Pick **Display**, start recording, then stop. Confirm the file is saved under `~/Movies/CaptureThis/`.
- Pick **Window** or **Application** and confirm the recording completes successfully.

### Cancel Flow

- Start a countdown and press **Escape** → verify recording is cancelled and HUD hides.
- During picker selection, press **Cancel** in the picker → verify the app returns to idle.
- During recording, press **Escape** → verify recording is discarded and file is deleted.

### Notifications

- After recording finishes, verify a system notification appears.
- Click **Open** and ensure the file opens in the default player.
- Click **Reveal in Finder** and ensure the file is selected in Finder.

### Recent Recordings

- Confirm the most recent recording appears in the popover list.
- Open and reveal actions work from the context menu.
