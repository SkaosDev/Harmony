# app/

iPhone app (Swift 6, SwiftUI, iOS 18.0+, iPhone only). Bundle ID `com.firestarter.harmony`.

Open `app/Harmony.xcodeproj` in Xcode 27.2. The `Harmony/` and `HarmonyTests/` folders are
*synchronized folders*: a file added on disk is part of the target without editing
`project.pbxproj`.

Build and test from the repository root (or through XcodeBuildMCP):

```sh
xcodebuild test -project app/Harmony.xcodeproj -scheme Harmony \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

The `Harmony` scheme is shared (`xcshareddata/`), so it exists for every team member.
