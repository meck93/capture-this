# CaptureThis

A lightweight, native macOS menu bar app for screen recording — with optional camera overlay and system audio. No cloud, no bloat, no Electron. Just hit record.

## Why CaptureThis?

macOS has built-in screen recording, but it's buried in menus and limited in features. Most third-party tools are heavy Electron apps with subscriptions and cloud dependencies. CaptureThis sits quietly in your menu bar and lets you capture your screen in seconds — completely offline, completely free.

**Built for people who record screens often:** developers capturing bug reports, PMs recording demos, remote workers making async updates, or educators creating quick tutorials.

## Features

- **Menu bar–only** — no Dock icon, no Cmd-Tab clutter, always one click away
- **Fast** — start recording in under 2 seconds (after a 3-second countdown)
- **Screen, window, or app capture** — pick exactly what you want via the native macOS picker
- **Camera overlay** — picture-in-picture via macOS Presenter Overlay (no janky custom bubbles)
- **System audio + microphone** — capture both with simple on/off toggles
- **Global hotkey** — start/stop recording without touching the mouse
- **100% local** — no cloud, no accounts, no telemetry. Your recordings stay on your machine
- **CLI included** — `CaptureThisCLI` for scripting and automation
- **Lightweight** — native Swift + SwiftUI, minimal resource usage

## Requirements

- macOS 15+ (Sequoia)
- Apple Silicon

## Install

### From source

```bash
# Install mise (if you don't have it)
# https://mise.jdx.dev

git clone https://github.com/meck93/capture-this.git
cd capture-this
mise install
mise run generate
mise run build
mise run install
```

This builds the app and copies it to `/Applications`.

### Release build

```bash
mise run generate
mise run release-build
mise run package
```

Artifacts (`.app.zip` and `.dmg`) are written to `artifacts/`.

## Usage

1. Launch **CaptureThis** — it appears in your menu bar
2. Click the menu bar icon → **Record**
3. Pick a screen, window, or app from the system picker
4. A 3-second countdown starts, then you're recording
5. Click the menu bar icon → **Stop** (or press the global hotkey)
6. Your recording is saved locally and a notification confirms it

**Tips:**
- Press **Escape** during countdown to cancel
- Enable camera overlay via the macOS Video menu bar for picture-in-picture
- Toggle microphone and system audio in the settings

### CLI

```bash
# List available capture sources
capture-this list

# Record a specific source
capture-this record

# Check permissions
capture-this permissions
```

## Development

```bash
mise run generate    # Generate Xcode project (XcodeGen)
mise run build       # Debug build
mise run test        # Run unit tests
mise run lint        # SwiftLint + SwiftFormat (lint mode)
mise run format      # Auto-format code
mise run ci          # Full CI pipeline (generate → lint → build → test)
```

### Project structure

```
Sources/
├── App/          # SwiftUI app entry point, app state
├── Core/         # Recording engine, models, services (framework)
├── Features/     # Menu bar UI, recording HUD, settings
├── Services/     # Camera, hotkey, notifications, file access
└── CLI/          # Command-line interface
Tests/            # Unit tests
Config/           # Info.plist, entitlements
Scripts/          # Build & packaging scripts
```

## Tech stack

| Area | Technology |
|------|-----------|
| Language | Swift |
| UI | SwiftUI + AppKit |
| Screen capture | ScreenCaptureKit (`SCStream` + `SCContentSharingPicker`) |
| Recording | `SCRecordingOutput` |
| Camera overlay | macOS Presenter Overlay |
| Project generation | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| Tool management | [mise](https://mise.jdx.dev) |
| Global hotkeys | [HotKey](https://github.com/soffes/HotKey) |

## License

[MIT](LICENSE)
