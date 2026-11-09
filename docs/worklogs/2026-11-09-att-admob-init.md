# 2026-11-09: ATT / AdMob startup bug (investigation only)

- The logic in `NYCBusNearbyApp.init` (`NYCBusNearbyApp.swift:18`) has been inverted since commit e6ac19d. It does nothing when the ATT status is `.notDetermined`, and calls `requestTrackingAuthorization` only when a choice already exists.
- On a fresh install nothing ever calls the request, so the status stays `.notDetermined`. The user never sees a prompt, and `MobileAds.shared.start` never runs.
- `NSUserTrackingUsageDescription` is missing from Info.plist and build settings. Apple requires it for the ATT request.
- The UMP SDK is linked but never used (no consent flow).
- Even with the condition fixed, `App.init` is too early to show the ATT prompt; the app must be active.
- No code changes. Reported the bug and two ways to fix it to the user.

## Fix (option 1: ask for tracking permission properly)
- New `NYCBusNearby/AdMob/AdsStarter.swift` (`@MainActor ObservableObject`):
  - When the scene becomes active, it asks for ATT permission if the status is `.notDetermined`. If the status stays `.notDetermined` (the prompt was skipped), it retries once after 1 s.
  - It then calls `MobileAds.shared.start` whatever the answer, and sets `adsStarted`.
  - It runs once per launch.
- `ContentView`:
  - Owns the `AdsStarter`.
  - Calls it from `.onChange(of: scenePhase, initial: true)` when the scene is `.active`.
  - Shows `BannerAd` only after `adsStarted`, with a 50 pt placeholder until then, so the first ad request goes out after the user answers the prompt.
- `NYCBusNearbyApp`: removed the inverted ATT/AdMob code from `init` and the unused imports.
- `project.pbxproj`:
  - Added `INFOPLIST_KEY_NSUserTrackingUsageDescription` to Debug and Release.
  - Registered `AdsStarter.swift` in the target.
- Verified: the simulator build succeeds, and the built Info.plist contains the usage description.
- Not yet verified on a simulator or device: that the prompt appears, and that the banner loads after it.
- Follow-ups for the user:
  - Update the App Store privacy label to say the app tracks users.
  - Decide whether a UMP consent form is needed (EEA/UK).

## Follow-up: async `MobileAds.start`
- Xcode suggested the async alternative to `MobileAds.shared.start(completionHandler: nil)`.
- Replaced it with `_ = await MobileAds.shared.start()`. `adsStarted` (and so the banner) now waits until the SDK finishes setting up or times out.
- Rebuilt: the build succeeds with no AdsStarter warnings and no Swift 6 Sendable diagnostics.
