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

[0.1.0]: https://github.com/synheart-ai/synheart-behavior-swift/releases/tag/v0.1.0
