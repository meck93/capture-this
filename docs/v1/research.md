# Product Requirements Document: macOS Screen Recorder with Camera Overlay

**Product Name:** ReelCam (working title)  
**Version:** V1.0  
**Date:** January 2026  
**Author:** Moritz  

---

## 1. Executive Summary

ReelCam is a native macOS screen recording application similar to Loom, designed for creating quick demos, tutorials, and async video communications. The app enables users to record their screen with an optional webcam overlay (picture-in-picture bubble), with all processing done locally without requiring cloud services or subscriptions.

**Key Value Proposition:** A lightweight, privacy-focused, offline-first screen recorder that's always available in the menu bar for quick capture with professional-quality output.

---

## 2. Problem Statement

### Current Pain Points

1. **Cloud Dependency:** Most screen recording tools (Loom, etc.) require accounts, subscriptions, and upload to cloud services
2. **Privacy Concerns:** Sensitive work content shouldn't leave local machines
3. **Complexity:** Full-featured video editors are overkill for quick demos
4. **macOS Native Experience:** Electron-based apps feel sluggish and non-native

### Target Users

- Developers creating bug reports and code walkthroughs
- Product managers recording demos and feature explanations
- Remote workers creating async updates for teammates
- Educators preparing tutorial content
- Anyone needing quick screen recordings with face overlay

---

## 3. Product Goals for V1

| Goal | Success Criteria |
|------|------------------|
| Quick to start | Recording begins within 2 seconds of clicking "record" |
| Minimal UI | Menu bar app with popover, no dock icon |
| Professional output | 1080p+ video, 30fps minimum, H.264/HEVC codec |
| Camera overlay | Draggable, resizable bubble with shape options |
| Local-first | Zero network requests required for core functionality |
| Lightweight | < 50MB app size, < 200MB RAM during recording |

---

## 4. Technical Architecture

### 4.1 Core Technology Stack

| Component | Technology | Rationale |
|-----------|------------|-----------|
| **Language** | Swift 6.x | Native performance, modern async/await, ScreenCaptureKit integration |
| **UI Framework** | SwiftUI + AppKit | SwiftUI for views, AppKit for menu bar integration |
| **Screen Capture** | ScreenCaptureKit | Apple's modern API (macOS 12.3+), high performance, fine-grained filtering |
| **Camera Capture** | AVFoundation | AVCaptureSession for webcam input |
| **Video Compositing** | Metal / Core Image | GPU-accelerated compositing of screen + camera frames |
| **Video Writing** | AVAssetWriter or SCRecordingOutput | Real-time encoding to disk |
| **Package Manager** | Swift Package Manager | Native dependency management |

---

## 4A. ScreenCaptureKit Deep Dive

ScreenCaptureKit is Apple's modern framework for screen capture on macOS, introduced in macOS 12.3 (Monterey). It replaces the deprecated `AVCaptureScreenInput` and provides high-performance, GPU-accelerated capture with fine-grained content filtering.

### Core API Classes

| Class | Purpose | Key Properties/Methods |
|-------|---------|------------------------|
| **SCStream** | Central object for capture streaming | `startCapture()`, `stopCapture()`, `addStreamOutput()`, `updateConfiguration()` |
| **SCShareableContent** | Enumerates available capture sources | `displays`, `windows`, `applications`, `excludingDesktopWindows()` |
| **SCContentFilter** | Defines what content to capture | Display-based or window-based filters, include/exclude apps |
| **SCStreamConfiguration** | Configures capture quality/format | Resolution, frame rate, pixel format, audio settings |
| **SCStreamOutput** | Protocol for receiving captured frames | `stream(_:didOutputSampleBuffer:of:)` |
| **SCContentSharingPicker** | System UI for content selection (macOS 14+) | No permission prompt needed, user-driven selection |
| **SCRecordingOutput** | Direct-to-file recording (macOS 15+) | Simplifies recording without manual AVAssetWriter |
| **SCScreenshotManager** | Single-frame capture (macOS 14+) | `captureImage(contentFilter:configuration:)` |

### SCShareableContent - Discovering Capture Sources

```swift
// Get all shareable content (displays, windows, apps)
let content = try await SCShareableContent.excludingDesktopWindows(
    false,                    // Include desktop windows
    onScreenWindowsOnly: true // Only visible windows
)

// Access available sources
let displays: [SCDisplay] = content.displays
let windows: [SCWindow] = content.windows  
let apps: [SCRunningApplication] = content.applications

// SCDisplay properties
display.displayID      // CGDirectDisplayID
display.width          // Int (pixels)
display.height         // Int (pixels)
display.frame          // CGRect

// SCWindow properties
window.windowID        // CGWindowID
window.title           // String?
window.frame           // CGRect
window.owningApplication // SCRunningApplication?
window.isOnScreen      // Bool
window.windowLayer     // Int

// SCRunningApplication properties
app.bundleIdentifier   // String
app.applicationName    // String
app.processID          // pid_t
```

### SCContentFilter - Two Filter Types

**1. Display-Independent Window Filter** (follows window across displays):

```swift
// Capture a single window, follows it to any display
let filter = SCContentFilter(desktopIndependentWindow: selectedWindow)
```

**2. Display-Dependent Filters** (capture from specific display):

```swift
// Capture entire display, excluding specific apps
let excludedApps = apps.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
let filter = SCContentFilter(
    display: selectedDisplay,
    excludingApplications: excludedApps,
    exceptingWindows: []  // Windows to include even if app is excluded
)

// Capture specific windows only on a display
let filter = SCContentFilter(
    display: selectedDisplay,
    including: [window1, window2],
    exceptingWindows: []
)

// Capture specific apps only on a display  
let filter = SCContentFilter(
    display: selectedDisplay,
    includingApplications: [keynoteApp, safariApp],
    exceptingWindows: []
)
```

**Important:** Audio capture is always at the application level, even with window filters. If you filter a single Safari window, you'll get audio from ALL Safari windows.

### SCStreamConfiguration - Quality & Performance

```swift
let config = SCStreamConfiguration()

// ═══════════════════════════════════════════════════════════════
// VIDEO CONFIGURATION
// ═══════════════════════════════════════════════════════════════

// Resolution - CRITICAL: Handle Retina displays correctly
let scaleFactor = NSScreen.main?.backingScaleFactor ?? 2.0
config.width = Int(CGFloat(display.width) * scaleFactor)
config.height = Int(CGFloat(display.height) * scaleFactor)

// Frame rate (frames per second)
config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 fps
config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 fps

// Pixel format
config.pixelFormat = kCVPixelFormatType_32BGRA  // Best for display/Metal
config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange // Best for encoding

// Color space
config.colorSpaceName = CGColorSpace.sRGB
config.colorSpaceName = CGColorSpace.displayP3

// Cursor visibility
config.showsCursor = true

// Queue depth (frames buffered, 1-8, default 3)
config.queueDepth = 5  // More = uses more memory, but smoother

// Background color for multi-window capture
config.backgroundColor = .black

// ═══════════════════════════════════════════════════════════════
// AUDIO CONFIGURATION
// ═══════════════════════════════════════════════════════════════

// System audio capture
config.capturesAudio = true
config.sampleRate = 48000        // 44100 or 48000
config.channelCount = 2          // Stereo

// Exclude own app's audio (prevent feedback)
config.excludesCurrentProcessAudio = true

// ═══════════════════════════════════════════════════════════════
// MICROPHONE CAPTURE (macOS 15+)
// ═══════════════════════════════════════════════════════════════

config.captureMicrophone = true
config.microphoneCaptureDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID

// ═══════════════════════════════════════════════════════════════
// HDR CAPTURE (macOS 14+)
// ═══════════════════════════════════════════════════════════════

// For local display (capture + render on same screen)
config.captureDynamicRange = .hdrLocalDisplay

// For sharing/streaming to other devices
config.captureDynamicRange = .hdrCanonicalDisplay

// HDR requires 10-bit pixel format
config.pixelFormat = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
```

### SCStream - Creating and Managing Streams

```swift
// Create stream with filter and configuration
let stream = SCStream(filter: filter, configuration: config, delegate: self)

// Add output handlers (on dedicated dispatch queues)
let videoQueue = DispatchQueue(label: "com.app.video-capture")
let audioQueue = DispatchQueue(label: "com.app.audio-capture")

try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: audioQueue) // macOS 15+

// Start capture
try await stream.startCapture()

// Update configuration on-the-fly (no restart needed!)
try await stream.updateConfiguration(newConfig)
try await stream.updateContentFilter(newFilter)

// Stop capture
try await stream.stopCapture()
```

### SCStreamOutput Protocol - Receiving Frames

```swift
extension ScreenCaptureManager: SCStreamOutput {
    func stream(_ stream: SCStream, 
                didOutputSampleBuffer sampleBuffer: CMSampleBuffer, 
                of type: SCStreamOutputType) {
        
        switch type {
        case .screen:
            // Video frame - check status first
            guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                  let statusValue = attachments.first?[.status] as? Int,
                  let status = SCFrameStatus(rawValue: statusValue),
                  status == .complete else {
                return // Skip incomplete frames
            }
            
            // Get frame metadata
            if let contentRect = attachments.first?[.contentRect] as? CGRect,
               let scaleFactor = attachments.first?[.scaleFactor] as? CGFloat,
               let contentScale = attachments.first?[.contentScale] as? CGFloat {
                // Use metadata for proper display
            }
            
            // Get pixel buffer for processing
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            
            // Process frame (composite with camera, write to file, etc.)
            processVideoFrame(pixelBuffer, timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
            
        case .audio:
            // System audio samples
            processAudioSample(sampleBuffer)
            
        case .microphone:
            // Microphone samples (macOS 15+)
            processMicrophoneSample(sampleBuffer)
            
        @unknown default:
            break
        }
    }
}
```

### SCStreamDelegate - Error Handling

```swift
extension ScreenCaptureManager: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        // Handle stream errors (permission revoked, display disconnected, etc.)
        print("Stream stopped with error: \(error.localizedDescription)")
    }
    
    // Presenter Overlay started (macOS 14+)
    func stream(_ stream: SCStream, outputEffectDidStart didStart: Bool) {
        if didStart {
            // User enabled Presenter Overlay - may want to hide your own camera bubble
            print("Presenter Overlay enabled")
        }
    }
}
```

### SCContentSharingPicker - System UI (macOS 14+)

The system picker provides a native UI for content selection and **doesn't require screen recording permission** (since the user explicitly chooses what to share).

```swift
// Configure picker options
let pickerConfig = SCContentSharingPickerConfiguration()
pickerConfig.allowedPickerModes = [.singleWindow, .multipleWindows, .singleApplication, .singleDisplay]

// Exclude your own app from picker
let excludedApps = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    .applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
pickerConfig.excludedBundleIDs = [Bundle.main.bundleIdentifier!]

// Get singleton picker
let picker = SCContentSharingPicker.shared
picker.add(self)  // Add observer
picker.defaultConfiguration = pickerConfig
picker.isActive = true

// Present picker
picker.present()

// Handle picker events
extension ContentPicker: SCContentSharingPickerObserver {
    func contentSharingPicker(_ picker: SCContentSharingPicker, 
                              didUpdateWith filter: SCContentFilter, 
                              for stream: SCStream?) {
        // User selected content - use the filter to create/update stream
        self.selectedFilter = filter
        startCapture(with: filter)
    }
    
    func contentSharingPicker(_ picker: SCContentSharingPicker, 
                              didCancelFor stream: SCStream?) {
        // User cancelled selection
    }
    
    func contentSharingPickerDidRequestNewStream(_ picker: SCContentSharingPicker) {
        // System requested a new stream (e.g., from Video menu bar)
    }
}
```

### SCRecordingOutput - Direct-to-File Recording (macOS 15+)

Simplifies recording by handling AVAssetWriter internally:

```swift
// Configure recording output
let recordingConfig = SCRecordingOutputConfiguration()
recordingConfig.outputURL = URL(fileURLWithPath: "/path/to/recording.mp4")
recordingConfig.outputFileType = .mp4    // or .mov
recordingConfig.videoCodecType = .hevc   // or .h264

// Create recording output with delegate
let recordingOutput = SCRecordingOutput(configuration: recordingConfig, delegate: self)

// Add to existing stream (before starting capture for guaranteed first frame)
try stream.addRecordingOutput(recordingOutput)

// Start capture (recording starts automatically)
try await stream.startCapture()

// Stop recording (can stop recording while continuing stream)
try stream.removeRecordingOutput(recordingOutput)

// Handle recording events
extension Recorder: SCRecordingOutputDelegate {
    func recordingOutputDidStartRecording(_ output: SCRecordingOutput) {
        print("Recording started")
    }
    
    func recordingOutputDidFinishRecording(_ output: SCRecordingOutput) {
        print("Recording finished - file ready at \(output.configuration.outputURL)")
    }
    
    func recordingOutput(_ output: SCRecordingOutput, didFailWithError error: Error) {
        print("Recording failed: \(error)")
    }
}
```

### Presenter Overlay (macOS 14+)

Apple's built-in "camera bubble" feature that composites webcam onto screen share:

- **Automatically available** when your app uses both SCStream AND AVCaptureSession with camera
- **User-controlled** via Video menu bar or Control Center (no API to enable/disable)
- **Two modes:** Small (floating bubble) and Large (segmented presenter behind content)
- **Your app receives composited frames** - no additional work needed

```swift
// Detect when Presenter Overlay is enabled
func stream(_ stream: SCStream, outputEffectDidStart didStart: Bool) {
    if didStart {
        // Consider hiding your custom camera bubble since system is providing one
        cameraOverlayWindow.isVisible = false
    } else {
        cameraOverlayWindow.isVisible = true
    }
}

// Control alert behavior (when to show "Presenter Overlay available" alert)
config.presenterOverlayAlertSetting = .never      // Never show
config.presenterOverlayAlertSetting = .system     // Follow system setting (default)
config.presenterOverlayAlertSetting = .always     // Always show
```

### Feature Availability by macOS Version

| Feature | macOS 12.3 | macOS 13 | macOS 14 | macOS 15 |
|---------|------------|----------|----------|----------|
| Basic screen capture | ✅ | ✅ | ✅ | ✅ |
| System audio capture | ✅ | ✅ | ✅ | ✅ |
| Window/App filtering | ✅ | ✅ | ✅ | ✅ |
| HDR capture | ❌ | ✅ | ✅ | ✅ |
| SCContentSharingPicker | ❌ | ❌ | ✅ | ✅ |
| Presenter Overlay | ❌ | ❌ | ✅ | ✅ |
| SCScreenshotManager | ❌ | ❌ | ✅ | ✅ |
| Microphone capture | ❌ | ❌ | ❌ | ✅ |
| SCRecordingOutput | ❌ | ❌ | ❌ | ✅ |

### Critical Gotchas & Best Practices

**1. Retina Display Handling:**
```swift
// WRONG - will produce blurry/small capture on Retina
config.width = display.width
config.height = display.height

// CORRECT - multiply by scale factor
let scale = NSScreen.main?.backingScaleFactor ?? 2.0
config.width = Int(CGFloat(display.width) * scale)
config.height = Int(CGFloat(display.height) * scale)
```

**2. Frame Status Checking:**
```swift
// Always check frame status before processing
guard let status = attachments.first?[.status] as? Int,
      SCFrameStatus(rawValue: status) == .complete else {
    return // Skip incomplete, idle, blank, or suspended frames
}
```

**3. Static Screen Handling:**
ScreenCaptureKit only sends frames when content changes. For a 10-second recording of a static screen, you may only receive 1 frame! Solutions:
- Use `CMTimebaseSetRate` to force timing
- Duplicate the last frame to fill gaps when writing to AVAssetWriter
- Use SCRecordingOutput (macOS 15+) which handles this automatically

**4. Excluding Your Own App:**
```swift
// Prevent capturing your own UI (recording controls, etc.)
let myApp = apps.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
let filter = SCContentFilter(
    display: display,
    excludingApplications: [myApp].compactMap { $0 },
    exceptingWindows: []
)
```

**5. Permission Flow:**
- Traditional SCShareableContent API requires "Screen Recording" permission
- SCContentSharingPicker (macOS 14+) does NOT require permission (user explicitly selects)
- First capture attempt triggers system permission dialog
- After denial, must guide user to System Settings > Privacy & Security > Screen Recording

---

### 4.2 Minimum System Requirements

**Required: macOS 15.0 (Sequoia) or later**

| Requirement | Specification |
|-------------|---------------|
| **macOS Version** | 15.0 (Sequoia) or later |
| **Processor** | Apple Silicon (M1 or later) - required for Presenter Overlay |
| **Camera** | Built-in or external webcam |
| **Permissions** | Camera, Microphone (Screen Recording NOT required with SCContentSharingPicker) |

**Why macOS 15?**
- `SCRecordingOutput` - Direct-to-file recording without manual AVAssetWriter
- Built-in microphone capture in `SCStream`
- `SCContentSharingPicker` - No screen recording permission needed
- `Presenter Overlay` - Apple handles camera bubble compositing
- Dramatically simpler implementation

---

## 4B. Swift & SwiftUI Best Practices

### Architecture Pattern: Lightweight MVVM

For ReelCam, we'll use a **lightweight MVVM** pattern optimized for SwiftUI's reactive nature:

```
┌─────────────────────────────────────────────────────────────┐
│                    ReelCam Architecture                      │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │    Views     │◄──►│  ViewModels  │◄──►│   Services   │   │
│  │  (SwiftUI)   │    │ (@Observable)│    │   (Actors)   │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
│         │                   │                   │            │
│         │                   │                   │            │
│         ▼                   ▼                   ▼            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │                      Models                           │   │
│  │              (Structs, Enums, DTOs)                   │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Modern Swift Patterns (2024/2025)

**1. Use `@Observable` macro (iOS 17+ / macOS 14+) instead of `ObservableObject`:**

```swift
// ❌ Old way - verbose, requires @Published for each property
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var duration: TimeInterval = 0
    @Published var error: Error?
}

// ✅ New way - cleaner, automatic property observation
@Observable
final class RecordingViewModel {
    var isRecording = false
    var duration: TimeInterval = 0
    var error: Error?
}
```

**2. Use `@State` for view-owned ViewModels:**

```swift
// ✅ Correct - view owns the ViewModel
struct RecordingView: View {
    @State private var viewModel = RecordingViewModel()
    
    var body: some View {
        // ...
    }
}

// ❌ Wrong - @ObservedObject may cause re-initialization
struct RecordingView: View {
    @ObservedObject var viewModel = RecordingViewModel() // Don't do this!
}
```

**3. Use Swift Concurrency (async/await) consistently:**

```swift
@Observable
final class RecordingViewModel {
    var isRecording = false
    
    private let captureService: CaptureService
    
    func startRecording() async throws {
        isRecording = true
        try await captureService.start()
    }
    
    func stopRecording() async throws -> URL {
        defer { isRecording = false }
        return try await captureService.stop()
    }
}
```

**4. Use Actors for thread-safe shared state:**

```swift
actor CaptureService {
    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    
    func start(filter: SCContentFilter, configuration: SCStreamConfiguration) async throws {
        stream = SCStream(filter: filter, configuration: configuration, delegate: nil)
        // ...
    }
}
```

### SwiftUI Performance Best Practices

**1. Minimize view re-renders by extracting subviews:**

```swift
// ❌ Bad - entire view re-renders when timer updates
struct RecordingView: View {
    @State var viewModel = RecordingViewModel()
    
    var body: some View {
        VStack {
            Text("Recording: \(viewModel.duration)")  // Changes every second
            ExpensiveControlsView()  // Re-rendered unnecessarily!
        }
    }
}

// ✅ Good - only TimerDisplay re-renders
struct RecordingView: View {
    @State var viewModel = RecordingViewModel()
    
    var body: some View {
        VStack {
            TimerDisplay(duration: viewModel.duration)  // Isolated updates
            ExpensiveControlsView()  // Not affected by timer
        }
    }
}

struct TimerDisplay: View {
    let duration: TimeInterval
    var body: some View {
        Text("Recording: \(duration.formatted())")
    }
}
```

**2. Use `let` for immutable view inputs:**

```swift
// ✅ Good - SwiftUI can skip re-render if value unchanged
struct StatusIndicator: View {
    let isRecording: Bool  // Immutable input
    
    var body: some View {
        Circle()
            .fill(isRecording ? .red : .gray)
    }
}
```

**3. Avoid heavy computation in `body`:**

```swift
// ❌ Bad - computed on every render
var body: some View {
    List(recordings.sorted(by: { $0.date > $1.date })) { ... }
}

// ✅ Good - computed once, cached in ViewModel
var body: some View {
    List(viewModel.sortedRecordings) { ... }
}
```

**4. Use `.task` for async work, not `.onAppear`:**

```swift
// ✅ Good - automatically cancelled when view disappears
var body: some View {
    ContentView()
        .task {
            await viewModel.loadInitialState()
        }
}
```

### Project Folder Structure

```
ReelCam/
├── ReelCamApp.swift              # App entry point
├── App/
│   ├── AppState.swift            # Global app state (@Observable)
│   └── AppDelegate.swift         # Menu bar setup (AppKit bridge)
│
├── Features/
│   ├── Recording/
│   │   ├── RecordingView.swift
│   │   ├── RecordingViewModel.swift
│   │   └── Components/
│   │       ├── RecordingControls.swift
│   │       └── TimerDisplay.swift
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   └── SettingsViewModel.swift
│   │
│   └── MenuBar/
│       ├── MenuBarView.swift
│       └── MenuBarManager.swift
│
├── Services/
│   ├── CaptureService.swift      # SCStream + SCRecordingOutput (Actor)
│   ├── PermissionService.swift   # Camera/Mic permission checks
│   └── FileService.swift         # Save location handling
│
├── Models/
│   ├── RecordingSettings.swift   # User preferences (struct)
│   ├── Recording.swift           # Recording metadata (struct)
│   └── CaptureConfiguration.swift
│
├── Extensions/
│   ├── URL+Extensions.swift
│   └── TimeInterval+Formatting.swift
│
└── Resources/
    ├── Assets.xcassets
    └── Localizable.strings
```

### Key SwiftUI Patterns for ReelCam

**1. Environment for dependency injection:**

```swift
// Define environment key
struct CaptureServiceKey: EnvironmentKey {
    static let defaultValue: CaptureService = CaptureService()
}

extension EnvironmentValues {
    var captureService: CaptureService {
        get { self[CaptureServiceKey.self] }
        set { self[CaptureServiceKey.self] = newValue }
    }
}

// Use in views
struct RecordingView: View {
    @Environment(\.captureService) private var captureService
}
```

**2. ViewModels as extensions (cleaner namespacing):**

```swift
struct RecordingView: View {
    @State private var viewModel = ViewModel()
    // ...
}

extension RecordingView {
    @Observable
    final class ViewModel {
        var isRecording = false
        // ...
    }
}
```

**3. Prefer composition over inheritance:**

```swift
// ✅ Good - composable, reusable
struct RecordingButton: View {
    let isRecording: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "stop.circle.fill" : "record.circle")
        }
    }
}
```

### Common Pitfalls to Avoid

| Pitfall | Problem | Solution |
|---------|---------|----------|
| `@ObservedObject` with inline init | ViewModel recreated on each render | Use `@StateObject` or `@State` with `@Observable` |
| Heavy work in `body` | Blocks main thread, janky UI | Move to ViewModel or background task |
| Too many `@State` properties | Hard to track, scattered logic | Consolidate into single ViewModel |
| Force unwrapping optionals | Crashes | Use `guard let`, `if let`, or `??` |
| Ignoring `MainActor` | UI updates from background thread | Mark ViewModels with `@MainActor` |
| Nested `ObservableObject` | Child changes don't trigger updates | Use `@Observable` macro (fixes this) |

### 4.3 Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           ReelCam App                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │   Menu Bar UI   │    │  Settings View  │    │ Recording HUD   │     │
│  │   (SwiftUI)     │    │   (SwiftUI)     │    │  (NSWindow)     │     │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘     │
│           │                      │                      │               │
│           └──────────────────────┼──────────────────────┘               │
│                                  │                                       │
│  ┌───────────────────────────────┴───────────────────────────────────┐  │
│  │                     RecordingCoordinator                          │  │
│  │  - Manages recording state machine                                │  │
│  │  - Coordinates capture sources                                    │  │
│  │  - Handles start/stop/pause                                       │  │
│  └───────────────────────────────┬───────────────────────────────────┘  │
│                                  │                                       │
│  ┌───────────────┐    ┌─────────┴─────────┐    ┌───────────────────┐   │
│  │ ScreenCapture │    │  VideoCompositor  │    │   CameraCapture   │   │
│  │   Manager     │    │    (Metal)        │    │     Manager       │   │
│  │               │    │                   │    │                   │   │
│  │ SCStream      │───▶│ Composites screen │◀───│ AVCaptureSession  │   │
│  │ SCDisplay     │    │ + camera frames   │    │ AVCaptureDevice   │   │
│  │ SCWindow      │    │ into single       │    │ VideoDataOutput   │   │
│  └───────────────┘    │ output buffer     │    └───────────────────┘   │
│                       └─────────┬─────────┘                             │
│                                 │                                       │
│  ┌──────────────────────────────┴────────────────────────────────────┐  │
│  │                         VideoWriter                               │  │
│  │  - AVAssetWriter with AVAssetWriterInput                          │  │
│  │  - H.264/HEVC encoding                                            │  │
│  │  - Audio track from AVCaptureAudioDataOutput                      │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                 │                                       │
│                                 ▼                                       │
│                          📁 .mov/.mp4 file                              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Feature Specifications

### 5.1 Recording Modes

| Mode | Description | Priority |
|------|-------------|----------|
| **Screen + Camera** | Full screen or window with camera bubble overlay | P0 |
| **Screen Only** | Screen capture without camera | P0 |
| **Camera Only** | Webcam recording only (future) | P2 |

### 5.2 Screen Capture Options

#### Capture Source Selection

- **Full Screen:** Capture entire display (default)
- **Single Window:** Select specific application window
- **Display Selection:** Choose which monitor to record (multi-monitor support)

#### Implementation Notes

```swift
// Using SCShareableContent for display/window enumeration
let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
let displays = content.displays  // SCDisplay objects
let windows = content.windows    // SCWindow objects

// Create content filter
let filter = SCContentFilter(display: selectedDisplay, excludingWindows: [])

// Configure stream
let config = SCStreamConfiguration()
config.width = display.width * Int(display.scaleFactor)
config.height = display.height * Int(display.scaleFactor)
config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30fps
config.pixelFormat = kCVPixelFormatType_32BGRA
```

### 5.3 Camera Overlay (Picture-in-Picture)

#### Bubble Shapes

| Shape | Description |
|-------|-------------|
| **Circle** | Default Loom-style circular bubble |
| **Rounded Rectangle** | Softer corners for more face visibility |
| **Rectangle** | Full rectangular webcam view |

#### Bubble Properties

| Property | Options | Default |
|----------|---------|---------|
| Position | Any corner, draggable to custom position | Bottom-left |
| Size | Small (80px), Medium (120px), Large (160px), Custom | Medium |
| Border | None, Thin, Thick | Thin white |
| Shadow | On/Off | On |
| Mirroring | Horizontal flip | On (mirror mode) |

#### Implementation Approach

1. **Separate AVCaptureSession** for webcam input
2. **Metal shader** for real-time compositing:
   - Sample from screen texture
   - Sample from camera texture
   - Apply circular/rounded mask to camera
   - Composite at specified position
   - Output to single texture for AVAssetWriter

```swift
// Pseudocode for Metal compositor
fragment float4 compositeFragment(
    texture2d<float> screenTexture,
    texture2d<float> cameraTexture,
    constant CompositeParams& params
) {
    float4 screenColor = screenTexture.sample(coord);
    
    // Check if within bubble bounds
    if (isInBubbleRegion(coord, params.bubbleRect)) {
        float4 cameraColor = cameraTexture.sample(bubbleCoord);
        
        // Apply shape mask (circle, rounded rect, etc.)
        float mask = calculateMask(bubbleCoord, params.shape);
        
        return mix(screenColor, cameraColor, mask);
    }
    
    return screenColor;
}
```

### 5.4 Audio Capture

| Source | Description | Priority |
|--------|-------------|----------|
| **Microphone** | External/built-in mic input | P0 |
| **System Audio** | Application audio (requires ScreenCaptureKit audio) | P1 |
| **Both** | Mix mic + system audio | P1 |

#### Implementation

```swift
// Microphone via AVFoundation
let audioSession = AVCaptureSession()
let audioDevice = AVCaptureDevice.default(for: .audio)
let audioInput = try AVCaptureDeviceInput(device: audioDevice!)
audioSession.addInput(audioInput)

// System audio via ScreenCaptureKit (macOS 13+)
let config = SCStreamConfiguration()
config.capturesAudio = true
config.excludesCurrentProcessAudio = true  // Exclude app's own sounds
```

### 5.5 User Interface

#### Menu Bar App

- **Status Item:** Recording icon in menu bar (red dot when recording)
- **Popover UI:** SwiftUI view with:
  - Capture mode selector (Screen+Cam, Screen, Camera)
  - Screen/window picker
  - Camera preview thumbnail
  - Microphone selector
  - Record button
  - Recent recordings list

#### Recording Controls HUD

- **Floating panel** that appears during recording
- Semi-transparent, always-on-top window
- Controls: Stop, Pause/Resume, Cancel
- Timer display
- Can be hidden/shown via hotkey

#### Camera Bubble Overlay Window

- **Borderless NSWindow** positioned over all apps
- Level: `.screenSaver` or higher to stay on top
- Contains camera preview (not composited yet - just for positioning)
- Draggable to reposition
- Resize handles at corners

### 5.6 Keyboard Shortcuts

| Action | Default Shortcut | Customizable |
|--------|------------------|--------------|
| Start/Stop Recording | ⌘⇧5 | Yes |
| Pause/Resume | ⌘⇧P | Yes |
| Cancel Recording | Escape | No |
| Toggle Camera Bubble | ⌘⇧C | Yes |
| Open App | ⌘⇧R | Yes |

#### Implementation

Use `MASShortcut` or `HotKey` SPM packages for global hotkey registration.

### 5.7 Output Settings

| Setting | Options | Default |
|---------|---------|---------|
| **Format** | MOV, MP4 | MOV |
| **Codec** | H.264, HEVC | HEVC (Apple Silicon), H.264 (Intel) |
| **Quality** | Low, Medium, High, Lossless | High |
| **Frame Rate** | 24, 30, 60 fps | 30 |
| **Resolution** | Native, 1080p, 720p | Native |
| **Save Location** | Custom folder | ~/Movies/ReelCam |

### 5.8 Post-Recording Actions

| Action | Description | Priority |
|--------|-------------|----------|
| **Show in Finder** | Reveal file after recording | P0 |
| **Copy to Clipboard** | Copy file reference | P1 |
| **Quick Share** | AirDrop, Share Sheet | P2 |
| **Auto-open** | Open in QuickTime/Preview | P2 |

---

## 6. Data Flow

### Simplified Recording Pipeline (V1)

With our decision to use **SCRecordingOutput + Presenter Overlay**, the architecture is dramatically simpler:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    ReelCam V1 Recording Pipeline                             │
│                 (SCRecordingOutput + Presenter Overlay)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  User clicks "Record"                                                        │
│        │                                                                     │
│        ▼                                                                     │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │                    SCContentSharingPicker                           │     │
│  │              (System UI - no permission needed)                     │     │
│  │                                                                     │     │
│  │    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐          │     │
│  │    │ Display │   │ Window  │   │  App    │   │ Region  │          │     │
│  │    └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘          │     │
│  └─────────┼─────────────┼─────────────┼─────────────┼────────────────┘     │
│            └─────────────┴─────────────┴─────────────┘                       │
│                                   │                                          │
│                                   ▼                                          │
│                          SCContentFilter                                     │
│                                   │                                          │
│                                   ▼                                          │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │                           SCStream                                  │     │
│  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐ │     │
│  │  │ Screen + Camera  │  │   System Audio   │  │   Microphone     │ │     │
│  │  │ (via Presenter   │  │   (optional)     │  │   Audio          │ │     │
│  │  │  Overlay)        │  │                  │  │                  │ │     │
│  │  └────────┬─────────┘  └────────┬─────────┘  └────────┬─────────┘ │     │
│  └───────────┼─────────────────────┼─────────────────────┼───────────┘     │
│              │                     │                     │                  │
│              └─────────────────────┴─────────────────────┘                  │
│                                    │                                         │
│                                    ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────┐     │
│  │                       SCRecordingOutput                             │     │
│  │                                                                     │     │
│  │   • Handles all encoding (H.264/HEVC)                              │     │
│  │   • Handles all muxing                                              │     │
│  │   • Handles frame timing automatically                              │     │
│  │   • Handles audio/video sync                                        │     │
│  │   • Handles static screen (no frame? no problem!)                   │     │
│  └───────────────────────────────┬────────────────────────────────────┘     │
│                                  │                                           │
│                                  ▼                                           │
│                           📁 output.mov                                      │
│                   (Screen + Camera + Audio)                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Camera Overlay via Presenter Overlay

Apple's **Presenter Overlay** handles the camera bubble automatically:

```
┌────────────────────────────────────────────────────────────────┐
│                    Presenter Overlay Flow                       │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. App creates SCStream (for screen capture)                   │
│  2. App creates AVCaptureSession (for camera access)            │
│  3. macOS detects both are active                               │
│  4. Video menu bar shows Presenter Overlay option               │
│                                                                 │
│     ┌─────────────────────────────────────────────────┐        │
│     │  📹 Video Menu Bar                              │        │
│     │  ┌───────────────────────────────────────────┐ │        │
│     │  │ Presenter Overlay                         │ │        │
│     │  │  ○ Off                                    │ │        │
│     │  │  ● Small (floating bubble)               │ │        │
│     │  │  ○ Large (full presenter mode)           │ │        │
│     │  └───────────────────────────────────────────┘ │        │
│     └─────────────────────────────────────────────────┘        │
│                                                                 │
│  5. User enables Small overlay                                  │
│  6. macOS composites camera bubble into SCStream output         │
│  7. SCRecordingOutput writes composited frames to file          │
│                                                                 │
│  Result: Camera bubble in recording with ZERO custom code!      │
│                                                                 │
└────────────────────────────────────────────────────────────────┘
```

### What We DON'T Need to Build

Thanks to SCRecordingOutput + Presenter Overlay, we can skip:

| Component | Why Not Needed |
|-----------|----------------|
| ❌ Metal shader compositor | Presenter Overlay composites automatically |
| ❌ Custom camera bubble window | Presenter Overlay provides it |
| ❌ AVAssetWriter setup | SCRecordingOutput handles it |
| ❌ Frame timing synchronization | SCRecordingOutput handles it |
| ❌ Static frame duplication | SCRecordingOutput handles it |
| ❌ Manual audio/video sync | SCRecordingOutput handles it |
| ❌ Custom screen permission UI | SCContentSharingPicker handles it |

### Sequence Diagram

```
User          MenuBar        CaptureService       SCStream        Presenter
  │              │                 │                  │             Overlay
  │──"Record"───►│                 │                  │                │
  │              │──startCapture()►│                  │                │
  │              │                 │──presentPicker()►│                │
  │              │                 │                  │                │
  │◄─────────────────────System Picker UI────────────►│                │
  │──select──────────────────────────────────────────►│                │
  │              │                 │◄──SCContentFilter│                │
  │              │                 │                  │                │
  │              │                 │──createStream()─►│                │
  │              │                 │──addRecording()─►│                │
  │              │                 │──enableCamera()──┼───────────────►│
  │              │                 │──startCapture()─►│                │
  │              │                 │                  │                │
  │              │                 │  [Recording...]  │◄──composites───│
  │              │                 │                  │   camera       │
  │──"Stop"─────►│                 │                  │                │
  │              │──stopCapture()─►│                  │                │
  │              │                 │──stopCapture()──►│                │
  │              │                 │                  │                │
  │              │◄──outputURL─────│                  │                │
  │◄─"Save as?"──│                 │                  │                │
  │──location───►│                 │                  │                │
  │              │──moveFile()────►│                  │                │
  │◄──"Done!"────│                 │                  │                │
```

---

## 7. File/Folder Structure

Simplified structure reflecting our architecture decisions:

```
ReelCam/
├── ReelCamApp.swift                    # @main entry point
│
├── App/
│   ├── AppState.swift                  # @Observable global state
│   └── AppDelegate.swift               # NSApplicationDelegate for menu bar
│
├── Features/
│   ├── MenuBar/
│   │   ├── MenuBarView.swift           # SwiftUI popover content
│   │   └── MenuBarManager.swift        # NSStatusItem management
│   │
│   ├── Recording/
│   │   ├── RecordingView.swift         # Recording controls UI
│   │   ├── RecordingViewModel.swift    # @Observable view model
│   │   └── Components/
│   │       ├── RecordingHUD.swift      # Floating stop/pause controls
│   │       └── TimerDisplay.swift      # Recording duration display
│   │
│   └── Settings/
│       ├── SettingsView.swift          # Settings UI
│       └── SettingsViewModel.swift     # Settings state
│
├── Services/
│   ├── CaptureService.swift            # Actor: SCStream + SCRecordingOutput
│   ├── PickerService.swift             # SCContentSharingPicker wrapper
│   ├── CameraService.swift             # AVCaptureSession (enables Presenter Overlay)
│   └── PermissionService.swift         # Camera/Mic permission checks
│
├── Models/
│   ├── RecordingSettings.swift         # User preferences (struct)
│   ├── Recording.swift                 # Recording metadata (struct)
│   └── AppError.swift                  # Error types (enum)
│
├── Extensions/
│   ├── URL+Extensions.swift
│   └── TimeInterval+Formatting.swift
│
└── Resources/
    ├── Assets.xcassets
    ├── Localizable.strings
    └── Info.plist
```

**Notable simplifications:**
- No `Compositing/` folder - Presenter Overlay handles it
- No `Writing/` folder - SCRecordingOutput handles it
- No `BubbleMask.swift` or `Shaders.metal` - not needed
- Services are `actor` types for thread safety

---

## 8. Implementation Phases (Simplified - 4 Weeks)

With SCRecordingOutput + Presenter Overlay, the implementation is dramatically simpler.

### Phase 1: Foundation (Week 1)

- [ ] Project setup with SPM
- [ ] Menu bar app scaffold (NSStatusItem + SwiftUI popover)
- [ ] AppDelegate + AppState setup
- [ ] Basic SCContentSharingPicker integration
- [ ] Request Camera + Microphone permissions
- [ ] Basic SCStream + SCRecordingOutput (screen only, no audio)

**Deliverable:** App that records selected screen/window to MOV file

```swift
// Core recording flow - surprisingly simple!
let picker = SCContentSharingPicker.shared
picker.present()  // System UI handles selection

// After user selects content:
let config = SCRecordingOutputConfiguration()
config.outputURL = saveURL
config.outputFileType = .mov

let recordingOutput = SCRecordingOutput(configuration: config, delegate: self)
try stream.addRecordingOutput(recordingOutput)
try await stream.startCapture()  // Done!
```

### Phase 2: Camera + Audio (Week 2)

- [ ] AVCaptureSession setup (enables Presenter Overlay)
- [ ] Microphone capture via SCStreamConfiguration
- [ ] Detect when Presenter Overlay is enabled/disabled
- [ ] Recording HUD (floating stop button + timer)
- [ ] Save file dialog integration

**Deliverable:** Full recording with camera (via Presenter Overlay) + mic audio

```swift
// Enable camera for Presenter Overlay
let captureSession = AVCaptureSession()
let camera = AVCaptureDevice.default(for: .video)
let input = try AVCaptureDeviceInput(device: camera!)
captureSession.addInput(input)
captureSession.startRunning()  // Presenter Overlay now available!

// Enable microphone in SCStream
config.captureMicrophone = true
config.microphoneCaptureDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
```

### Phase 3: UI & Polish (Week 3)

- [ ] Menu bar popover UI (record button, recent recordings)
- [ ] Settings view (output location, format, quality)
- [ ] Global hotkeys (start/stop recording)
- [ ] Settings persistence (UserDefaults)
- [ ] Recording state indicators (menu bar icon changes)

**Deliverable:** Polished UI with all user-facing features

### Phase 4: Testing & Release (Week 4)

- [ ] Multi-monitor testing
- [ ] Performance profiling
- [ ] Edge case handling (permission denied, disk full, etc.)
- [ ] Error handling and user feedback
- [ ] App notarization
- [ ] README and documentation

**Deliverable:** Release-ready V1.0

### Timeline Comparison

| Approach | Timeline | Complexity |
|----------|----------|------------|
| **Original (Custom compositing)** | 10 weeks | High - Metal shaders, AVAssetWriter, frame sync |
| **Simplified (SCRecordingOutput)** | 4 weeks | Low - Apple handles everything |

### What Each Week Produces

```
Week 1: "It records the screen!"
        └── Core capture pipeline working
        
Week 2: "It records me too!"
        └── Camera via Presenter Overlay + microphone
        
Week 3: "It's actually usable!"
        └── Polished UI, hotkeys, settings
        
Week 4: "Ship it!"
        └── Tested, notarized, ready for users
```

---

## 9. Key Technical Challenges (Simplified)

With SCRecordingOutput + Presenter Overlay, most of the hard problems are solved by Apple. Here's what remains:

### 9.1 ~~Frame Synchronization~~ ✅ Solved by SCRecordingOutput

**Original Problem:** Screen and camera capture run at different rates and timing.

**Solution:** SCRecordingOutput handles all frame timing and synchronization automatically.

### 9.2 ~~Real-time Compositing~~ ✅ Solved by Presenter Overlay

**Original Problem:** GPU compositing must complete within frame budget (~33ms at 30fps).

**Solution:** Presenter Overlay composites the camera bubble automatically - no custom Metal code needed.

### 9.3 ~~Camera Bubble Window Z-Order~~ ✅ Solved by Presenter Overlay

**Original Problem:** Bubble preview must stay above content without appearing in recording.

**Solution:** Presenter Overlay is a system feature - macOS handles everything.

### 9.4 ~~Audio Latency~~ ✅ Solved by SCRecordingOutput

**Original Problem:** Audio/video desync is very noticeable.

**Solution:** SCRecordingOutput handles audio/video sync automatically.

---

### Remaining Challenges

#### 9.5 Menu Bar + SwiftUI Integration

**Problem:** SwiftUI doesn't natively support menu bar apps (NSStatusItem).

**Solution:**
```swift
// Use AppDelegate to create status item
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        let popover = NSPopover()
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
        popover.behavior = .transient
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "record.circle", accessibilityDescription: nil)
            button.action = #selector(togglePopover)
        }
    }
}
```

#### 9.6 Global Hotkeys

**Problem:** SwiftUI doesn't support global keyboard shortcuts.

**Solution:** Use the HotKey package:
```swift
import HotKey

let hotKey = HotKey(key: .r, modifiers: [.command, .shift])
hotKey.keyDownHandler = {
    // Toggle recording
}
```

#### 9.7 Presenter Overlay State Detection

**Problem:** Need to know when user enables/disables Presenter Overlay.

**Solution:** Implement `SCStreamDelegate`:
```swift
extension CaptureService: SCStreamDelegate {
    func stream(_ stream: SCStream, outputEffectDidStart didStart: Bool) {
        if didStart {
            // Presenter Overlay enabled - camera is now in the recording
            await MainActor.run { appState.presenterOverlayEnabled = true }
        } else {
            // Presenter Overlay disabled
            await MainActor.run { appState.presenterOverlayEnabled = false }
        }
    }
}
```

#### 9.8 Save Location Handling

**Problem:** Need to prompt user for save location after recording.

**Solution:** Use NSSavePanel:
```swift
func promptSaveLocation(suggestedName: String) async -> URL? {
    await withCheckedContinuation { continuation in
        DispatchQueue.main.async {
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.movie]
            panel.nameFieldStringValue = suggestedName
            panel.directoryURL = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first
            
            if panel.runModal() == .OK {
                continuation.resume(returning: panel.url)
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}
```

---

## 10. Dependencies (SPM)

```swift
// Package.swift dependencies
dependencies: [
    .package(url: "https://github.com/soffes/HotKey", from: "0.2.0"),
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
    .package(url: "https://github.com/sindresorhus/LaunchAtLogin", from: "5.0.0"),
]
```

| Package | Purpose |
|---------|---------|
| **HotKey** | Global keyboard shortcuts |
| **Sparkle** | Auto-updates (optional) |
| **LaunchAtLogin** | "Start at login" functionality |

---

## 11. Privacy & Permissions

### Required Entitlements

```xml
<!-- ReelCam.entitlements -->
<key>com.apple.security.device.camera</key>
<true/>
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

### Privacy Manifest

Required for App Store / notarization:

```xml
<!-- PrivacyInfo.xcprivacy -->
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array><string>CA92.1</string></array>
    </dict>
</array>
```

### Permission Request Flow

1. On first launch, show onboarding explaining needed permissions
2. Request Screen Recording permission (opens System Preferences)
3. Request Camera permission (system dialog)
4. Request Microphone permission (system dialog)
5. Guide user if any permission is denied

---

## 12. Out of Scope for V1

- Cloud upload/sharing
- Video editing (trim, cut, annotations)
- Drawing tools during recording
- Countdown timer before recording
- Scheduled recordings
- Virtual backgrounds for camera
- Multiple camera support
- GIF export
- Watermarks
- Team/workspace features

---

## 13. Success Metrics

| Metric | Target |
|--------|--------|
| Time to first recording | < 30 seconds from install |
| Recording start latency | < 2 seconds |
| Frame drops during recording | < 1% |
| App crash rate | < 0.1% |
| Memory usage during 10min recording | < 250MB |
| Output file size (1080p30, 5min) | < 150MB (HEVC) |

---

## 14. References & Resources

### Apple Documentation
- [ScreenCaptureKit Framework](https://developer.apple.com/documentation/screencapturekit)
- [SCStream](https://developer.apple.com/documentation/screencapturekit/scstream)
- [SCShareableContent](https://developer.apple.com/documentation/screencapturekit/scshareablecontent)
- [SCContentFilter](https://developer.apple.com/documentation/screencapturekit/sccontentfilter)
- [SCStreamConfiguration](https://developer.apple.com/documentation/screencapturekit/scstreamconfiguration)
- [SCContentSharingPicker](https://developer.apple.com/documentation/screencapturekit/sccontentsharingpicker)
- [SCRecordingOutput](https://developer.apple.com/documentation/screencapturekit/screcordingoutput)
- [AVFoundation Capture](https://developer.apple.com/documentation/avfoundation/capture_setup)
- [AVAssetWriter](https://developer.apple.com/documentation/avfoundation/avassetwriter)
- [Metal Best Practices](https://developer.apple.com/documentation/metal/gpu_programming_guide)

### WWDC Sessions (Essential Viewing)

**ScreenCaptureKit:**
- [Meet ScreenCaptureKit (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10156/) - Framework introduction, basic setup
- [Take ScreenCaptureKit to the next level (WWDC22)](https://developer.apple.com/videos/play/wwdc2022/10155/) - Advanced filters, window pickers, performance
- [What's new in ScreenCaptureKit (WWDC23)](https://developer.apple.com/videos/play/wwdc2023/10136/) - System picker, Presenter Overlay, screenshots
- [Capture HDR content with ScreenCaptureKit (WWDC24)](https://developer.apple.com/videos/play/wwdc2024/10088/) - HDR, microphone capture, SCRecordingOutput

**Camera & Video:**
- [What's new in camera capture (WWDC21)](https://developer.apple.com/videos/play/wwdc2021/10047/) - AVCaptureSession improvements
- [Advances in Camera Capture & Photo Segmentation (WWDC19)](https://developer.apple.com/videos/play/wwdc2019/225/) - Multi-camera PiP compositing

### Sample Code
- [Capturing screen content in macOS (Apple)](https://developer.apple.com/documentation/screencapturekit/capturing_screen_content_in_macos) - Official sample
- [ScreenCaptureKit-Recording-example (nonstrict)](https://github.com/nonstrict-hq/ScreenCaptureKit-Recording-example) - Recording to file with AVAssetWriter
- [reel by rselbach](https://github.com/rselbach/reel) - Menu bar screen recorder with camera overlay

### Technical Articles
- [Recording to disk using ScreenCaptureKit (Nonstrict)](https://nonstrict.eu/blog/2023/recording-to-disk-with-screencapturekit/) - Edge cases, Retina handling, AVAssetWriter setup
- [A look at ScreenCaptureKit on macOS Sonoma (Nonstrict)](https://nonstrict.eu/blog/2023/a-look-at-screencapturekit-on-macos-sonoma/) - Presenter Overlay, SCContentSharingPicker analysis

### Similar Products (for reference)
- **Loom** - Market leader, cloud-based
- **ooml.io** - Offline Loom alternative, local-first
- **Screen Studio** - Professional screen recordings with zoom effects
- **CleanShot X** - Screenshot/recording tool with annotation

---

## 15. Architecture Decisions (Resolved)

### ✅ Resolved Decisions

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | **SCContentSharingPicker vs Custom Picker** | **System Picker** | No permission dialog needed, native macOS UI, less code to maintain, users already familiar with it |
| 2 | **SCRecordingOutput vs AVAssetWriter** | **SCRecordingOutput** | Simpler implementation, Apple handles encoding/muxing, automatic static frame handling, microphone capture built-in |
| 3 | **Presenter Overlay Integration** | **Embrace it fully** | Apple's Presenter Overlay provides camera bubble automatically - we don't need to build a custom one. When user enables camera, Presenter Overlay composites it into the stream. We just receive the composited frames. |
| 4 | **Default capture mode** | **Full display + selection option** | Default to full display capture, but provide macOS screenshot-style selection UI (via SCContentSharingPicker) for window/region selection |
| 5 | **Audio mixing UI** | **None in V1** | Keep V1 simple - capture microphone audio only. System audio mixing adds complexity. |
| 6 | **Recording format** | **MOV** | Native macOS format, better QuickTime integration, lossless codec support |
| 7 | **Save behavior** | **Prompt for location** | Always prompt user for save location to ensure they know where files go |
| 8 | **Minimum macOS version** | **macOS 15.0 (Sequoia)** | Required for SCRecordingOutput and built-in microphone capture. Simplifies architecture significantly. |
| 9 | **Static screen handling** | **SCRecordingOutput handles it** | Apple's API automatically manages frame timing |
| 10 | **Retina scale factor** | **Use SCStreamConfiguration defaults** | SCRecordingOutput handles resolution automatically |

### 🎯 Key Architectural Insight: No Custom Camera Bubble Needed

**Critical Discovery:** With macOS 15's `SCContentSharingPicker` + `Presenter Overlay`, Apple provides the camera bubble functionality automatically:

1. When your app uses both `SCStream` (for screen) AND `AVCaptureSession` (for camera), macOS automatically makes Presenter Overlay available
2. User enables Presenter Overlay via the Video menu bar item
3. Apple composites the camera feed into the screen capture stream automatically
4. Your app receives the already-composited frames
5. Camera bubble is draggable, has background removal, and supports Small/Large modes

**What this means for ReelCam V1:**
- ❌ No need to build custom camera bubble UI
- ❌ No need for Metal shader compositing
- ❌ No need to manage separate camera/screen frame synchronization
- ✅ Just use SCRecordingOutput + enable camera access
- ✅ Let macOS handle all the compositing complexity

### Remaining Open Questions (V2+)

1. **Custom bubble shapes:** Should we offer custom bubble shapes beyond what Presenter Overlay provides? (Circles, rectangles, etc.)
2. **Recording countdown:** Add 3-2-1 countdown before recording starts?
3. **Quick actions:** Add annotation/drawing tools during recording?

---

*Document Version: 1.0*  
*Last Updated: January 2026*
