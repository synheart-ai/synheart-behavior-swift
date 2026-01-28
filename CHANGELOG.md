# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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


