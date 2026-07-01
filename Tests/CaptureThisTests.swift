@testable import CaptureThis
import CaptureThisCore
import XCTest

final class CaptureThisTests: XCTestCase {
  func testMenuBarRecordButtonTitles() {
    XCTAssertEqual(MenuBarView.recordButtonTitle(for: .idle), "Record")
    XCTAssertEqual(MenuBarView.recordButtonTitle(for: .recording(isPaused: false)), "Stop Recording")
    XCTAssertEqual(MenuBarView.recordButtonTitle(for: .recording(isPaused: true)), "Paused")
    XCTAssertEqual(MenuBarView.recordButtonTitle(for: .countdown(2)), "Counting down…")
    XCTAssertEqual(MenuBarView.recordButtonTitle(for: .pickingSource), "Picking source…")
    XCTAssertEqual(MenuBarView.recordButtonTitle(for: .stopping), "Stopping…")
  }

  func testMenuBarPauseResumeButtonTitle() {
    XCTAssertEqual(MenuBarView.pauseResumeButtonTitle(for: .recording(isPaused: false)), "Pause")
    XCTAssertEqual(MenuBarView.pauseResumeButtonTitle(for: .recording(isPaused: true)), "Resume")
    XCTAssertNil(MenuBarView.pauseResumeButtonTitle(for: .idle))
  }

  func testMenuBarRecordButtonDisabledStates() {
    XCTAssertFalse(MenuBarView.isRecordButtonDisabled(for: .idle))
    XCTAssertTrue(MenuBarView.isRecordButtonDisabled(for: .countdown(1)))
    XCTAssertTrue(MenuBarView.isRecordButtonDisabled(for: .pickingSource))
    XCTAssertTrue(MenuBarView.isRecordButtonDisabled(for: .stopping))
  }

  func testPermissionSetupStateBlocksRecordingUntilStatusesLoad() {
    XCTAssertTrue(PermissionSetupState().blocksRecording)
  }

  func testPermissionSetupStateBlocksRecordingForMissingRequiredItem() {
    let state = PermissionSetupState(items: [
      PermissionSetupItem(kind: .screenRecording, status: .granted, isRequired: true),
      PermissionSetupItem(kind: .saveFolder, status: .notDetermined, isRequired: true),
      PermissionSetupItem(kind: .notifications, status: .notDetermined, isRequired: false)
    ])

    XCTAssertTrue(state.blocksRecording)
  }

  func testPermissionSetupStateAllowsRecordingWhenRequiredItemsAreGranted() {
    let state = PermissionSetupState(items: [
      PermissionSetupItem(kind: .screenRecording, status: .granted, isRequired: true),
      PermissionSetupItem(kind: .saveFolder, status: .granted, isRequired: true),
      PermissionSetupItem(kind: .notifications, status: .notDetermined, isRequired: false)
    ])

    XCTAssertFalse(state.blocksRecording)
  }

  func testDeniedPermissionActionOpensSettings() {
    let item = PermissionSetupItem(kind: .camera, status: .denied, isRequired: true)
    XCTAssertEqual(item.actionTitle, "Open Settings")
  }

  func testRecordingHUDHelpers() {
    XCTAssertEqual(RecordingHUDView.pauseResumeSymbolName(for: .recording(isPaused: false)), "pause.fill")
    XCTAssertEqual(RecordingHUDView.pauseResumeSymbolName(for: .recording(isPaused: true)), "play.fill")
    XCTAssertNil(RecordingHUDView.pauseResumeSymbolName(for: .idle))

    XCTAssertEqual(RecordingHUDView.indicatorColorName(for: .recording(isPaused: false)), "red")
    XCTAssertEqual(RecordingHUDView.indicatorColorName(for: .recording(isPaused: true)), "orange")
    XCTAssertNil(RecordingHUDView.indicatorColorName(for: .idle))

    XCTAssertTrue(RecordingHUDView.usesTimeline(for: .recording(isPaused: false)))
    XCTAssertFalse(RecordingHUDView.usesTimeline(for: .recording(isPaused: true)))
    XCTAssertFalse(RecordingHUDView.usesTimeline(for: .idle))
  }
}
