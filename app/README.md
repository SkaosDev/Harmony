# app/

iPhone app (Swift 6, SwiftUI, iOS 18.0+, iPhone only). Bundle ID `com.firestarter.harmony`,
signed with the team `AZSWSR7P8Q`. Screens follow `docs/design/` exactly (see `CLAUDE.md`).

## First time

1. Open `app/Harmony.xcodeproj` in Xcode 27.2.
2. Copy `Harmony/Config.example.xcconfig` to `Harmony/Config.xcconfig` (ignored by Git) and fill
   in the Spotify Client ID (and later the Worker URL). Never commit it. Without it the app still
   builds, with empty values (demo mode only).

## Build and test

From the repository root (or through XcodeBuildMCP):

```sh
xcodebuild test -project app/Harmony.xcodeproj -scheme Harmony \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The `Harmony` scheme is shared (`xcshareddata/`), so it exists for every team member.

## Layout

| Path | Content |
|---|---|
| `Harmony/App/` | entry point, root view and tab bar, design tokens (`Theme`) |
| `Harmony/Features/` | SwiftUI screens, one folder per feature |
| `Harmony/Core/` | models (SwiftData) and pure logic: features, state, queue, scoring |
| `Harmony/Services/` | Spotify, HealthKit, demo providers, Worker client |
| `Harmony/Resources/` | asset catalog, then `muse.sqlite`, Core ML model, demo data |
| `Harmony/Info.plist` | URL scheme `harmony`, `spotify` query scheme, HealthKit text, config keys |
| `Harmony/Harmony.entitlements` | HealthKit |
| `Harmony/Harmony.xcconfig` | base build settings; includes `Config.xcconfig` if present |
| `HarmonyTests/` | unit tests (Swift Testing) |

`Harmony/` and `HarmonyTests/` are *synchronized folders*: a file added on disk joins the target
without editing `project.pbxproj`. Files that must **not** be copied into the app (`Info.plist`,
`.xcconfig`, `.gitkeep`) are listed as exceptions in `project.pbxproj` (Xcode › file inspector ›
Target Membership). Delete a folder's `.gitkeep` (and its exception) once the folder has real files.
