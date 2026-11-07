# 2026-11-07 — Cleanup and API key (plan item 5)

## Context
- Bus Time docs and a live test (see `2026-11-07-alerts-and-cancellations.md`) showed that SIRI and the OBA
  API enforce the key, and that GTFS-RT is documented as requiring one. So the app keeps sending a key.
- The user has requested and received a new Bus Time key.
- Plan for item 5:
  1. remove the EC2 server leftovers
  2. move the key out of source into a git-ignored xcconfig, using the new key
  3. later, retire the old key (it is public in git history since `bac9c15`)

## Step 1: remove EC2 server code and configuration
- `Model/MTAFeedConstant.swift`: removed `restUrlString`
  (`http://ec2-18-218-113-91.us-east-2.compute.amazonaws.com:8080/busfeedmonitor/json`) and the
  HTTP helper constants used only for it (`contentType`, `accept`, `applicationJson`,
  `applicationXWWWFormUrlencoded`, `post`). None were referenced anywhere. Only `apiKey` remains.
- `Info.plist`: removed `NSAppTransportSecurity`, which allowed insecure HTTP to all of `*.amazonaws.com`
  including subdomains. The app now uses the default ATS policy (HTTPS only).
- Kept: the `rrgtfsfeeds.s3.amazonaws.com` HTTPS URLs in `scripts/update_gtfs.py`. They point to MTA's GTFS
  bucket, not the EC2 server, and the script doesn't run in the app.
- No other references found (searched the source, the project file, and Info.plist for ec2, amazonaws,
  busfeedmonitor, restUrl, and NSAppTransport).

## Verification
- `plutil -lint Info.plist` OK. The built app's Info.plist has no `NSAppTransportSecurity`.
- iOS Simulator Debug build succeeded.
- Ran on a temporary iOS 26.5 simulator (deleted afterwards) at Times Square:
  - all three feeds downloaded (`result=[true, true, true]`, 0.46 s)
  - 13,465 stops loaded and nearby stops listed
  - the AdMob test banner loaded
  - no ATS errors in the log

## Status
- Not committed.

## Follow-up: step 1 committed
- Committed `7114142` ("chore: Remove leftover EC2 server code and ATS exception"), including this worklog.

## Step 2: move the API key out of source
- `Config/NYCBusNearby.xcconfig` (new, committed): the target's base configuration for Debug and Release. It
  has `#include? "Secrets.xcconfig"` (optional include, so a missing file doesn't stop the project from loading).
- `Config/Secrets.example.xcconfig` (new, committed): a template with an empty `MTA_BUS_TIME_API_KEY =` and
  the key request URL.
- `Config/Secrets.xcconfig`: the real key, git-ignored. **Not created; the user adds the new key here.**
- `.gitignore` (new; the repo had none): `Config/Secrets.xcconfig`, `xcuserdata/`, `DerivedData/`,
  `build/`, `.DS_Store`.
- `Info.plist`: `MTABusTimeAPIKey = $(MTA_BUS_TIME_API_KEY)`.
- `MTAFeedConstant.apiKey`: reads `MTABusTimeAPIKey` from the bundle and returns `?key=<key>`, or `""` if it
  is missing. Same format as before, so `MTAFeedDownloader` and MTAFeed are unchanged. The old literal key is
  removed from source.
- `project.pbxproj`: added a Config group with both xcconfig files, a `baseConfigurationReference` on the
  target's Debug and Release configurations, and a first build phase "Check MTA API Key" that fails with
  "error: MTA_BUS_TIME_API_KEY is not set. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig ..."
  when the setting is empty.
- `CLAUDE.md`: documented the key setup under Commands.

### Verification
- No key: the build fails (exit 65) with the error above.
- Key passed on the command line (old key, test only, not written to any file): the build succeeds, and the
  built Info.plist `MTABusTimeAPIKey` matches.
- A temporary `Config/Secrets.xcconfig` with a dummy UUID: git ignores it (`.gitignore:2`), the build
  succeeds, the built Info.plist carries the dummy value, and Release `-showBuildSettings` resolves it too.
  The temporary file was deleted afterwards.
- Not yet: a build with the user's new key and a live run using it.
