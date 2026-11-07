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
