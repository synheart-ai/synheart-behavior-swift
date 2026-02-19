# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2026-02-18

### Added

- `SynheartBehavior` main SDK class with initialize/dispose lifecycle.
- `BehaviorConfig` for configurable signal collection (input, attention, motion-lite).
- `BehaviorEvent` with type-safe factory methods: `scroll`, `tap`, `swipe`, `notification`, `call`, `typing`, `clipboard`, `appSwitch`.
- `BehaviorStats` for real-time behavioral metrics (typing cadence, scroll velocity, tap rate, stability index, fragmentation index).
- `BehaviorSessionSummary` with aggregated session metrics and deep-focus block detection.
- `SessionManager` for session lifecycle tracking and statistics aggregation.
- `EventBatcher` for configurable event batching and delivery.
- Signal collectors: `InputSignalCollector`, `ScrollSignalCollector`, `GestureSignalCollector`, `AttentionSignalCollector`.
- Single and batch event handler callbacks.
- Privacy-preserving design — timing-based signals only, no content capture.
- Thread-safe implementation with NSLock.
- Example: `BasicUsage.swift`.
- Unit tests covering initialization, sessions, events, stats, config, and disposal.
- GitHub Actions CI/CD workflows (ci.yml, release.yml).

## [0.2.0] - 2026-02-12

### Added

- **Clipboard and correction rates**: Typing session summary from Flux now includes `clipboard_activity_rate` and `correction_rate` (synheart-flux 0.3.0+). SDK sends `number_of_backspace`, `number_of_copy`, `number_of_paste`, `number_of_cut` (and `number_of_delete` as 0 on iOS) in typing events so Flux can compute these rates.
- **Public API for clipboard**: `SynheartBehavior.recordCopy()`, `recordPaste()`, and `recordCut()` so apps can report copy/paste/cut when the user performs those actions (e.g. from a custom text field that overrides `copy(_:)`/`paste(_:)`/`cut(_:)`).
- **Example: BehaviorTrackingTextField**: A `UITextField` subclass that notifies the SDK on copy/paste/cut; use it or wire the same calls in your own text input to get non-zero clipboard counts.
- **Typing metrics alignment**: Typing events now include `typing_cadence_variability` and `number_of_delete` (0 on iOS), matching Kotlin/Dart. Session results UI shows all typing metrics in the event card.

### Fixed

- **Cut vs backspace**: Text removed by **Cut** is no longer counted as backspace; only actual backspace/delete taps contribute to `backspace_count` and thus to `correction_rate`.
- **Taps while keyboard open**: Tap and long-press events are **not** counted when a text field or text view is first responder (keyboard open), so typing interaction is not double-counted as tap events.

### Changed

- Typing session summary is read from top-level HSI `meta` (Flux format); `clipboard_activity_rate` and `correction_rate` are included when available from Flux.
- Example app typing hint updated to mention Copy/Paste/Cut for testing clipboard counts.

## [0.1.0] - 2026-01-28

### Added

- **On-Demand Metrics Calculation**: New time range selection UI with date/time pickers (including milliseconds) to calculate behavioral metrics for custom time ranges within a session
- **System State Tracking**: Internet connectivity, Do Not Disturb status, and charging state detection
- **Device Context Tracking**: Average screen brightness, start orientation, and orientation change count
- **Events Timeline**: Comprehensive event timeline display with color-coded badges and detailed metrics
- **Raw HSI JSON Display**: Full HSI-compliant JSON output in session results view
- **Time Range HSI Output**: Console logging of HSI JSON for selected time ranges, matching Dart SDK functionality

### Fixed

- Fixed scroll jitter calculation always showing 0 by improving direction reversal detection sensitivity
- Fixed typing summary not appearing in UI by ensuring proper Flux integration and JSON extraction
- Fixed app switch count accuracy by aligning counting logic with Dart SDK (count on background, not foreground)
- Fixed gesture conflicts where scrolling was detected as swipe or tap events
- Fixed session spacing, notification summary fields, and system state data showing "N/A"
- Fixed events timeline displaying 0 events by properly passing and filtering events
- Fixed "Unknown event" appearing in timeline by filtering out unknown and app_switch events
- Fixed keyboard not dismissing when tapping outside text field
- Fixed iOS 13+ availability issues for UI elements (systemBackground, monospacedSystemFont)

### Changed

- **Flux Integration**: All behavioral and typing metric calculations now exclusively use synheart-flux (Rust library) version 0.1.1
- Removed native Swift calculation implementations for behavioral metrics
- Updated UI to match Dart SDK's card-based layout structure
- Improved scroll view discovery to ensure all scroll views are tracked
- Enhanced gesture recognizer configuration to prevent conflicts with system gestures
- Refactored typing session tracking to emit comprehensive typing events with all metrics
- Cleaned up codebase by removing debug print statements and unnecessary comments

### Technical Details

- All behavioral metrics (interaction intensity, distraction score, focus hint, deep focus blocks, etc.) are computed by Flux
- All typing session metrics (typing session count, average keystrokes, typing speed, etc.) are computed by Flux
- Native code now only handles event collection, session management, and Flux integration
- System state and device context data are injected into HSI JSON meta section

[Unreleased]: https://github.com/synheart-ai/synheart-behavior-swift/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/synheart-ai/synheart-behavior-swift/releases/tag/v0.3.0
[0.2.0]: https://github.com/synheart-ai/synheart-behavior-swift/releases/tag/v0.2.0
[0.1.0]: https://github.com/synheart-ai/synheart-behavior-swift/releases/tag/v0.1.0
