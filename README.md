# soundcore-pull

Pulls recordings off a Soundcore Work (Anker / Feishu D3200) AI voice recorder over Bluetooth LE,
straight to a Mac. No phone, no account, no cloud. Output is Ogg/Opus, a lossless copy of what the
device stores.

```
swift build -c release
.build/release/soundcore-pull list                 # device info and recordings
.build/release/soundcore-pull pull [--out DIR]     # download every recording not already in DIR
.build/release/soundcore-pull delete <fileId>...   # delete from the recorder
.build/release/soundcore-pull scan                 # diagnostic: print nearby BLE advertisements
```

Default output directory is `~/Music/Soundcore Work`. Files are named `yyyyMMdd-HHmmss-<fileId>.ogg`.

## Before you run it

- Take the recorder out of the case, or tap it, so it advertises. It does not advertise while
  asleep in the case or while connected to the phone.
- Close the Soundcore app on the phone, or switch the phone's Bluetooth off. The phone auto-connects
  to the recorder and only one central can hold the link.
- The first run asks for Bluetooth permission for your terminal application. Grant it in
  System Settings > Privacy & Security > Bluetooth.

## Tests

`swift test` needs the full Xcode toolchain for XCTest:

```
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

## Credits

The protocol comes from community work, not from this project:

- [tacshi/Soundcore](https://github.com/tacshi/Soundcore) documented the D3200 protocol
  (`PROTOCOL.md`) from the Anker SDK inside the Feishu Android app. Used as reference only.
- [Shawn-TKD/recording-bean-web](https://github.com/Shawn-TKD/recording-bean-web) (MIT) is a
  browser client for the same recorder. The framing, key exchange, chunk decryption and Ogg muxing
  here are a Swift port of its logic.

For interoperability with hardware you own.
