# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Removed
- The native runtime integration (`FluxBridge`, `FluxBehaviorProcessor`,
  `FluxError`) and all `Hsi*` payload structs. Higher-level metrics
  belong in `synheart-core-swift`.
- `endSessionWithHsi(sessionId:)`, `isFluxAvailable`, and
  `recordCopy()/Paste()/Cut()` on `SynheartBehavior`. Host apps that
  want clipboard tracking emit `BehaviorEvent.clipboard(...)` via
  `sendEvent(_:)`, matching the Flutter and Kotlin SDKs.
- `BehaviorError.fluxNotAvailable` and `.fluxProcessingFailed` cases.
- `INTEGRATION.md`, `SYNHEART_FLUX_INTEGRATION.md`, the `Frameworks/`
  directory placeholder for `SynheartFlux.xcframework`, and the
  `number_of_copy/paste/cut/delete` fields from typing event payloads
  (clipboard activity is now its own event type).

### Changed
- README rewritten to mirror the Flutter SDK's structure (source-
  available banner, full Privacy & Compliance breakdown, Architecture
  diagram, Troubleshooting section, "Not a Medical Device" notice).
- `Package.swift` carries no native-runtime build settings.

### Added
- `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  `.github/CODEOWNERS`, `.github/ISSUE_TEMPLATE/`,
  `.github/pull_request_template.md`,
  `.github/workflows/close-external-prs.yml`, `.github/dependabot.yml`.
- `Example/GUIDE.md` walkthrough mirroring the Flutter example guide.

### Platform support
- iOS 12.0+
- Swift 5.9+, Xcode 15.0+, Swift Package Manager

[Unreleased]: https://github.com/synheart-ai/synheart-behavior-swift/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/synheart-ai/synheart-behavior-swift/releases/tag/v0.3.1
