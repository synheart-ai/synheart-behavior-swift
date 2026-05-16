# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-05-15

API-parity pass. Brings the Swift SDK's surface into alignment with the
Flutter and Kotlin siblings so callers see the same shape across all
three platforms.

### Breaking
- `BehaviorEvent`: rename `type` → `eventType` and `payload` → `metrics`
  to match the canonical wire format (`event_type` / `metrics`).
- `SynheartBehavior.startSession()` now returns a `BehaviorSession`
  object with `.sessionId`, `.startTimestamp`, `.end() throws`, and
  `.getCurrentDuration()`. Callers that read the session ID can use
  `try sdk.startSession().sessionId`.
- Minimum iOS deployment target bumped from 12.0 to 13.0 (required for
  `AsyncStream` and `async`/`await`). `.ephemeral` notification
  authorization is gated behind `#available(iOS 14.0, *)`.

### Added
- `events: AsyncStream<BehaviorEvent>` — async-iteration API mirroring
  the Kotlin `onEvent: Flow` and Flutter `onEvent: Stream`. Coexists
  with the existing `setEventHandler` callback via internal fan-out.
- `checkNotificationPermission() async -> Bool` and
  `requestNotificationPermission() async -> Bool` via
  `UNUserNotificationCenter`. iOS-no-op `checkCallPermission` /
  `requestCallPermission` for signature parity with Flutter/Kotlin.
- `BehaviorSession` wrapper class.
- Nested types on `BehaviorSessionSummary` matching Kotlin/Flutter:
  `MotionState`, `DeviceContext`, `ActivitySummary`, `DeepFocusBlock`,
  `BehavioralMetricsStruct`, `NotificationSummary`, `SystemState`,
  `TypingMetrics`, `TypingSessionSummary`. ML-scored and aggregate
  fields default to `nil`/zeros until a downstream consumer populates
  them.

### Tests
- All 33 SDK tests pass on the renamed surface.

## [0.3.1] - 2026-05-07

Open-source launch release.

The SDK is now a pure behavioral signal collector. Higher-level
behavioral inference (HSI fusion, focus / distraction modeling, rolling
baselines) has moved to the Synheart Core SDK, which consumes the
events this package emits. This SDK no longer carries any native runtime
dependency.

### Public surface
The SDK collects privacy-preserving behavioral signals (taps, scrolls,
swipes, app switches, idle gaps, typing session counts) on iOS. No
text, content, or PII is captured. Per-session aggregates are exposed
on `BehaviorSessionSummary` and real-time stats on `BehaviorStats`.

- `SynheartBehavior`, `BehaviorConfig`, `BehaviorEvent`,
  `BehaviorEventType`, `BehaviorSessionSummary`, `BehaviorStats`,
  `BehaviorError`.
- Event-handler callback API (`setEventHandler`, `setBatchEventHandler`)
  for real-time behavioral events.
- Session-tracking API with summaries; manual stats polling.
- `BehaviorEvent.clipboard(sessionId:action:context:)` factory + `sendEvent(_:)`
  for host-app clipboard tracking.

### Notes
- Host apps that need clipboard tracking emit
  `BehaviorEvent.clipboard(sessionId:action:context:)` via
  `sendEvent(_:)`, matching the Flutter and Kotlin SDKs.

### Platform support
- iOS 12.0+
- Swift 5.9+, Xcode 15.0+, Swift Package Manager

[Unreleased]: https://github.com/synheart-ai/synheart-behavior-swift/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/synheart-ai/synheart-behavior-swift/releases/tag/v0.4.0
