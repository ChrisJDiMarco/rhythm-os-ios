# Rhythm OS

Rhythm OS is a native SwiftUI iOS concept app for restoring biological rhythm instead of optimizing raw screen time. It uses a circadian dashboard, morning light anchoring, HRV breathing resets, app-gate intent checks, notification batching, evening downshift routines, and a weekly rhythmicity report.

## Status

This is a runnable native iOS prototype.

- Built with SwiftUI
- Apple Health integration path through HealthKit
- Screen Time/app shielding path through FamilyControls and ManagedSettings
- Local simulator fallback loop for interventions
- Unit-tested rhythm scoring engine

## Open In Xcode

1. Open `Rhythm.xcodeproj`.
2. Select the `Rhythm` scheme.
3. Run on an iPhone simulator or physical iPhone.

HealthKit and Screen Time shielding require user authorization and real-device Apple entitlements for full behavior. In Simulator, Rhythm OS uses mock Health data plus local intervention logs so the app remains functional during development.

## Verification

```sh
xcodebuild -project Rhythm.xcodeproj -scheme Rhythm -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## Project Structure

- `Rhythm/` - SwiftUI app source
- `Rhythm/Engine/` - rhythm scoring and phase engine
- `Rhythm/Services/` - HealthKit, notifications, and app shielding services
- `Rhythm/Store/` - app state and persistence
- `Rhythm/Screens/` - feature screens
- `RhythmTests/` - unit tests
- `docs/` - product requirement document
