# Rhythm OS Requirement Document

## Goal

Turn the static Rhythm OS iOS concept into a functional native iOS app that reads Apple Health data, computes body-rhythm states, supports real user actions, and degrades cleanly in Simulator or when Apple-restricted permissions are unavailable.

## Core Product Requirements

1. HealthKit-backed dashboard
   - Request HealthKit authorization.
   - Read daily HRV, heart rate, resting heart rate, steps, distance, exercise minutes, sleep, workouts, mindful minutes, and daylight exposure where available.
   - Show mock data in Simulator or denied-permission states so the app remains inspectable.

2. Rhythm engine
   - Compute rhythmicity score from daylight, HRV, sleep, movement, mindful resets, and pickup/app-budget proxies.
   - Derive user states: morning light needed, focus phase, sympathetic spike, app friction, notification batching, evening downshift, weekly report.
   - Keep scoring deterministic and unit-testable.

3. Functional interventions
   - Morning Light: start an outdoor-light session timer and optionally log a walk-style session.
   - Breathing Reset: run a 90-second breathing protocol, provide haptics, and write a mindful session to HealthKit.
   - Evening Downshift: persist routine completion, send local reminders, and expose tomorrow's first task.
   - Weekly Report: calculate the last 7 days from live or mock samples.

4. Screen Time / App Gate
   - Use FamilyControls and ManagedSettings when authorization and entitlement are present.
   - Let the user select distracting apps/categories.
   - Apply shields during configured downshift or focus windows.
   - Provide an entitlement-safe fallback in Simulator and non-approved builds.

5. Quality bar
   - Production SwiftUI structure with services, state store, and testable engine.
   - No hardcoded secrets or backend dependency.
   - Build cleanly for iOS Simulator.
   - Include tests for rhythm scoring and state derivation.

## Known Platform Constraints

- HealthKit data is sparse or unavailable in Simulator; mock data must remain first-class.
- Time in daylight depends on Apple Health availability from compatible devices and user permission.
- Third-party apps cannot globally intercept all notifications. Rhythm OS will model batching and use local notifications plus Screen Time app shielding where Apple allows it.
- FamilyControls / ManagedSettings require user approval and may require Apple entitlement approval for distribution.

## Delivery Definition

- App compiles and launches in iPhone Simulator.
- Health authorization flow exists and routes through real HealthKit APIs.
- Dashboard and reports render from a single `RhythmSnapshot`.
- Breathing and morning sessions execute user-visible timers.
- App gate settings compile behind availability checks and fail gracefully without entitlement.
- Unit tests pass for the Rhythm Engine.
