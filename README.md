# Soundcore Pull

Small macOS app that copies recordings off a Soundcore Work (Anker / Feishu D3200) AI voice
recorder over Bluetooth LE into iCloud Drive › Soundcore Work. No phone, no account, no cloud
service. Output is Ogg/Opus, a lossless copy of what the device stores.

SwiftUI, macOS 26+, no third-party packages. The Xcode GUI is never opened.

## What it does

Leave the app open. When the recorder is awake and not held by the phone, the app connects,
lists its recordings, and pulls anything not already in the iCloud folder. It re-checks every
15 seconds. The toolbar has Show in Finder and Delete from Recorder (only for recordings that are
already in iCloud).

Files are named `yyyyMMdd-HHmmss-<fileId>.ogg`. The file id is the recording's start time as a
Unix timestamp, and it is what marks a recording as already downloaded.

## Build and run

- `project.yml` is the source of truth; `SoundcorePull.xcodeproj` is generated and git-ignored.
- `scripts/build.sh` — xcodegen + build.
- `scripts/run.sh` — build, then launch the app.
- `scripts/test.sh` — unit tests.
- `Local.xcconfig` (git-ignored) holds `DEVELOPMENT_TEAM`; `scripts/env.sh` creates a stub.

First launch asks for Bluetooth permission. Signing asks for the keychain password for the
Apple Development key; choose Always Allow once.

## Recorder notes

- It does not advertise while asleep in the case or while connected to the phone. Take it out of
  the case or tap it, and close the Soundcore app on the phone.
- USB on the case is charge-only.
- Protocol layout: `SoundcorePull/Protocol` (frames, ECDH/HKDF session, AES-CTR file decryption,
  Ogg/Opus muxing, blocking CoreBluetooth session). The sync loop is `Model/Syncer.swift`.

## Credits

The protocol comes from community work, not from this project:

- [tacshi/Soundcore](https://github.com/tacshi/Soundcore) documented the D3200 protocol
  (`PROTOCOL.md`) from the Anker SDK inside the Feishu Android app. Used as reference only.
- [Shawn-TKD/recording-bean-web](https://github.com/Shawn-TKD/recording-bean-web) (MIT) is a
  browser client for the same recorder. The framing, key exchange, chunk decryption and Ogg muxing
  here are a Swift port of its logic.

For interoperability with hardware you own.
