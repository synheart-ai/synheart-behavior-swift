# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.1] - 2026-05-06

Open-source launch release. Public API and documentation are scrubbed
of internal Flux integration references; behavioral signal collection
matches the v0.3.0 capability set.

### Public surface
The SDK collects privacy-preserving behavioral signals (taps, scrolls,
swipes, app switches, idle gaps, typing session counts) on iOS. No
text, content, or PII is captured. Behavioral and typing metrics are
surfaced through `BehaviorSessionSummary` (`behavioralMetrics`,
`typingMetrics`, `deepFocusBlocks`).

- `SynheartBehavior`, `BehaviorConfig`, `BehaviorEvent`,
  `BehaviorEventType`, `BehaviorSessionSummary`, `BehaviorStats`,
  `BehaviorError`.
- Event-handler callback API (`setEventHandler`, `setBatchEventHandler`)
  for real-time behavioral events.
- Session-tracking API with summaries; manual stats polling.
- On-demand metrics for ended sessions:
  `calculateMetricsForTimeRange()`.

### Changed
- README rewritten to remove public exposure of internal Flux
  integration: dropped the "Required: synheart-flux" install section,
  `synheart-flux 0.1.1+` requirement, `SynheartFlux.xcframework`
  references, `FluxBridge.shared.behaviorToHsi(...)` example, "All
  metrics computed via Flux" claim, the `endSessionWithHsi` /
  `isFluxAvailable` API table rows, and the
  `HsiBehaviorPayload` / `FluxBridge` / `FluxBehaviorProcessor` /
  `BehaviorError.fluxNotAvailable` / `.fluxProcessingFailed` Key
  Types references.
- README performance puffery (`<150 KB compiled, <2% CPU,
  <500 KB memory`) removed (unverified).
- README "six types of behavioral events" wording aligned with the
  actual 8-value `BehaviorEventType` enum.
- Author block dropped from README to match org-wide convention.
- `synheart-flux` is now declared optional in `Package.swift`, not
  required.

### Note
- The `endSessionWithHsi(sessionId:)`, `isFluxAvailable`, and
  `recordCopy()/Paste()/Cut()` symbols remain in the public Swift
  source for now; only README references were dropped pending a
  follow-up alignment with the Flutter / Kotlin SDKs.

### Platform support
- iOS 12.0+
- Swift 5.9+, Xcode 15.0+, Swift Package Manager

[Unreleased]: https://github.com/synheart-ai/synheart-behavior-swift/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/synheart-ai/synheart-behavior-swift/releases/tag/v0.3.1
