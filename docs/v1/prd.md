Below is a **clean, V1-only updated PRD** that incorporates all your answers and removes ambiguity.
This is written as an **implementation-ready spec**: an engineer should be able to build directly from this without re-deciding product behavior.

---

# Product Requirements Document (Updated): CaptureThis for macOS

**Product Name:** CaptureThis
**Version:** V1.0
**Target Platform:** macOS 15+ (Sequoia)
**App Type:** Menu bar–only native macOS app
**Last Updated:** January 2026

---

## 1. Executive Summary

CaptureThis is a lightweight, native macOS menu bar application for recording screen content with optional camera overlay and audio. It is **offline-first**, **local-only**, and optimized for fast, low-friction recording using Apple’s modern ScreenCaptureKit APIs.

V1 deliberately relies on **system-provided functionality** (SCContentSharingPicker, SCRecordingOutput, Presenter Overlay) to minimize complexity and maximize reliability.

---

## 2. Goals & Non-Goals

### Goals (V1)

* Start recording in under 2 seconds (excluding countdown)
* Zero cloud dependency
* Native macOS UX
* Minimal UI, menu bar–only
* Professional-quality output with minimal configuration

### Non-Goals (Explicitly Out of Scope for V1)

* Custom camera bubble UI or shapes
* Video editing (trim, annotate, etc.)
* Cloud upload or sharing
* Multi-display or region capture
* macOS < 15 support

---

## 3. Target Users

* Developers recording bug reports or walkthroughs
* Product managers recording demos
* Remote workers creating async updates
* Educators creating short tutorials

---

## 4. Platform & System Requirements

| Requirement | Specification                        |
| ----------- | ------------------------------------ |
| macOS       | **15.0 (Sequoia) or later**          |
| CPU         | Apple Silicon                        |
| App type    | Menu bar agent (no Dock, no Cmd-Tab) |
| Permissions | Camera, Microphone                   |
| Network     | Not required                         |

---

## 5. Core Architectural Decisions (Locked)

| Area           | Decision                              |
| -------------- | ------------------------------------- |
| Screen capture | `SCStream` + `SCContentSharingPicker` |
| Recording      | `SCRecordingOutput`                   |
| Camera overlay | **System Presenter Overlay only**     |
| Video writing  | Apple-managed (no AVAssetWriter)      |
| Audio          | Microphone + System Audio             |
| UI             | SwiftUI + AppKit                      |
| Sandbox        | Allowed, with one-time folder access  |

---

## 6. Recording Capabilities (V1)

### 6.1 Capture Sources

Exactly **one** of the following per recording:

* Single display
* Single window
* Single application

Selection is done exclusively via **SCContentSharingPicker**.

No region selection. No multi-source capture.

---

### 6.2 Camera Overlay

* Camera overlay is provided **only** via **macOS Presenter Overlay**.
* App does **not** implement a custom camera bubble.
* User enables/disables overlay via the system Video menu bar.
* App detects overlay state via `SCStreamDelegate`.

**Behavior:**

* Camera preview is always-on once permission is granted.
* Presenter Overlay becomes available automatically during recording.
* App does not control size, shape, or position.

---

### 6.3 Audio Capture

| Source       | Supported |
| ------------ | --------- |
| Microphone   | ✅         |
| System audio | ✅         |
| Mixing UI    | ❌ (V1)    |

**Behavior:**

* Both mic and system audio are captured when enabled.
* Simple on/off toggles in UI.
* No per-source volume controls in V1.

---

## 7. Recording Lifecycle & State Machine

### States

```
Idle
 → Countdown
 → PickingSource
 → Recording
 → Stopping
 → Completed
 → Idle
```

### Error / Exit States

* `Cancelled`
* `Error`

---

### 7.1 Countdown

* Default countdown: **3 seconds**
* Shown after pressing Record
* Cancelable via Escape
* Recording starts immediately after countdown ends

---

### 7.2 Start Conditions

Recording starts only when:

* Countdown completes
* User has selected capture source
* Required permissions are granted

---

### 7.3 Stop / Cancel

* **Stop**: finalizes file and shows notification
* **Cancel**: discards recording and deletes temp output

---

## 8. Output & File Management

### 8.1 Save Location

* Files are saved automatically to:

  ```
  ~/Movies/CaptureThis/
  ```
* Folder is created on first run if missing.

**Sandbox note:**
On first launch, the app requests **one-time folder access** and stores a security-scoped bookmark.

---

### 8.2 File Naming

Format:

```
CaptureThis_<ISO8601>.mov
```

Example:

```
CaptureThis_2026-01-27T14-03-22+01-00.mov
```

Filesystem-safe separators only.

---

### 8.3 Post-Recording Notification

After completion:

* System notification with actions:

  * **Reveal in Finder**
  * **Open**

---

## 9. Recent Recordings

### Behavior

* Keep **20 most recent recordings**
* Oldest entries are dropped automatically

### Storage

* Lightweight index stored in:

  ```
  Application Support/CaptureThis/recordings.json
  ```

Each entry contains:

* File URL (bookmark if needed)
* Created timestamp
* Duration (optional)
* Capture type (display/window/app)

### Actions

* Reveal in Finder
* Open

---

## 10. User Interface

### 10.1 App Presence

* Menu bar icon only
* No Dock icon
* Not visible in Cmd-Tab
* All interaction via menu bar popover or HUD

---

### 10.2 Menu Bar Popover

Contains:

* Capture source selector (Display / Window / Application)
* Toggles:

  * Camera
  * Microphone
  * System audio
* Record button
* Recent recordings list
* Settings entry

---

### 10.3 Recording HUD

* Appears during Countdown and Recording
* Always-on-top floating panel
* Default position: top-right of recorded display
* Controls:

  * Stop
  * Pause / Resume
  * Timer
* Must be excluded from capture via `SCContentFilter`

---

## 11. Keyboard Shortcuts (Defaults)

| Action         | Shortcut | Customizable |
| -------------- | -------- | ------------ |
| Start / Stop   | ⌘⇧R      | ✅            |
| Pause / Resume | ⌘⇧P      | ✅            |
| Cancel         | Escape   | ❌            |
| Toggle HUD     | ⌘⇧H      | ✅            |
| Open App       | ⌘⇧C      | ✅            |

If hotkey registration fails, app must surface a clear error and allow reassignment.

---

## 12. Permissions

### Required

* Camera
* Microphone

### Flow

* Requested when enabling camera preview or starting recording
* Simple system dialogs only
* No custom Screen Recording permission UX

---

## 13. Implementation Phases (4 Weeks)

### Week 1

* Menu bar app scaffold
* Picker → SCStream → SCRecordingOutput
* Screen-only recording

### Week 2

* Camera preview + Presenter Overlay
* Mic + system audio
* Recording HUD
* Countdown

### Week 3

* Popover UI
* Settings
* Recent recordings
* Global hotkeys

### Week 4

* Error handling
* Performance testing
* Notarization
* Release

---

## 14. Success Metrics

| Metric                  | Target  |
| ----------------------- | ------- |
| Time to first recording | < 30s   |
| Start latency           | < 2s    |
| Frame drops             | < 1%    |
| Crash rate              | < 0.1%  |
| 5-min 1080p HEVC file   | < 150MB |

---

## 15. Explicit V2+ Candidates (Non-V1)

* Custom camera bubble UI
* Region capture
* Audio mixing controls
* Video editing
* Cloud sharing
* Countdown customization

---

If you want, next steps could be:

* a **1-page engineering kickoff brief**
* a **task breakdown per week**
* or a **risk checklist specific to ScreenCaptureKit + Presenter Overlay**

