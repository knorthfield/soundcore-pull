import Foundation

let usage = """
usage: soundcore-pull list
       soundcore-pull pull [--out DIR]
       soundcore-pull delete <fileId>...
       soundcore-pull scan            (diagnostic: print all BLE advertisements for 10 s)

Pulls recordings off a Soundcore Work (D3200) recorder over Bluetooth LE.
Default output directory: ~/Music/Soundcore Work
"""

func fail(_ message: String) -> Never {
    fputs("error: \(message)\n", stderr)
    exit(1)
}

func formatBytes(_ bytes: UInt32) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
}

func formatDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds.rounded())
    return String(format: "%d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
}

let fileNameDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter
}()

let displayDate: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
}()

func connect() -> Recorder {
    let recorder = Recorder()
    print("scanning for soundcore Work...")
    do {
        try recorder.connect()
    } catch {
        fail("\(error)")
    }
    print("connected to \(recorder.name)")
    return recorder
}

func fetchDeviceInfo(_ recorder: Recorder) throws -> DeviceInfo {
    let reply = try recorder.request(Frames.getDeviceInfo(), type: 0x01, id: 0x01, timeout: 8, "device info")
    return DeviceInfo.parse(reply.payload)
}

func fetchRecordings(_ recorder: Recorder) throws -> [RecordingEntry] {
    var entries: [UInt32: RecordingEntry] = [:]
    for page in UInt16(0)..<50 {
        let reply = try recorder.request(Frames.listFiles(page: page), type: 0x1B, id: 0x0E, timeout: 8, "recording list page \(page)")
        let pageEntries = RecordingEntry.parseList(reply.payload)
        for entry in pageEntries { entries[entry.fileId] = entry }
        if pageEntries.count < 10 { break }
    }
    return entries.values.sorted { $0.fileId < $1.fileId }
}

func printRecordings(_ entries: [RecordingEntry]) {
    if entries.isEmpty {
        print("no recordings on device")
        return
    }
    print("\n  fileId      started               duration   size")
    for entry in entries {
        print("  \(entry.fileId)  \(displayDate.string(from: entry.startDate))   \(formatDuration(entry.estimatedDuration))    \(formatBytes(entry.sizeBytes))")
    }
}

func alreadyDownloaded(_ fileId: UInt32, in directory: URL) -> Bool {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
    return names.contains { $0.hasSuffix("-\(fileId).ogg") }
}

func pull(_ entry: RecordingEntry, recorder: Recorder, crypto: DeviceCrypto, to directory: URL) throws {
    if !crypto.hasSession {
        let reply = try recorder.request(Frames.handshake(publicKey: crypto.publicKey), type: 0x2E, id: 0x01, timeout: 12, "encryption handshake")
        try crypto.completeHandshake(reply.payload)
    }
    defer { crypto.clearFile(entry.fileId) }

    var audio = Data()
    var expected = entry.sizeBytes
    var chunks = 0
    try recorder.send(Frames.startExport(fileId: entry.fileId))
    while true {
        let frame = try recorder.next(timeout: 90, waitingFor: "file data for \(entry.fileId)")
        guard frame.type == 0x1A || frame.type == 0x1B else { continue }
        switch frame.id {
        case 0x07:
            let head = try crypto.prepareFile(frame.payload)
            if head.fileSize > 0 { expected = head.fileSize }
        case 0x08, 0x12:
            let raw = frame.raw
            var offset = 9
            while raw.count - offset >= 165 {
                let sequence = raw.u32le(at: offset)
                offset += 5
                let encrypted = Data(raw[offset..<(offset + 160)])
                offset += 160
                audio.append(try crypto.decryptChunk(fileId: entry.fileId, sequence: sequence, data: encrypted))
                if offset < raw.count { offset += 1 }
                chunks += 1
            }
            if chunks % 25 == 0 {
                let percent = expected > 0 ? min(100, audio.count * 100 / Int(expected)) : 0
                print("\r  \(percent)%  \(formatBytes(UInt32(audio.count)))", terminator: "")
                fflush(stdout)
            }
        case 0x0A:
            print("\r  100%  \(formatBytes(UInt32(audio.count)))")
            guard !audio.isEmpty else { fail("device returned no audio for \(entry.fileId)") }
            let name = "\(fileNameDate.string(from: entry.startDate))-\(entry.fileId).ogg"
            try OggOpus.mux(audio).write(to: directory.appendingPathComponent(name))
            print("  saved \(name)")
            return
        default:
            continue
        }
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else {
    print(usage)
    exit(2)
}

switch command {
case "list":
    let recorder = connect()
    defer { recorder.disconnect() }
    do {
        let info = try fetchDeviceInfo(recorder)
        let usedKB = info.totalKB >= info.freeKB ? info.totalKB - info.freeKB : 0
        let battery = info.batteryPercent.map { "\($0)%" } ?? "?"
        print("firmware \(info.firmware)  serial \(info.serial)  battery \(battery)\(info.charging ? " (charging)" : "")  storage \(usedKB / 1024) / \(info.totalKB / 1024) MB used\(info.recording ? "  RECORDING" : "")")
        printRecordings(try fetchRecordings(recorder))
    } catch {
        fail("\(error)")
    }

case "pull":
    var directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/Soundcore Work")
    if arguments.count >= 3, arguments[1] == "--out" {
        directory = URL(fileURLWithPath: (arguments[2] as NSString).expandingTildeInPath)
    } else if arguments.count != 1 {
        fail(usage)
    }
    do {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    } catch {
        fail("cannot create \(directory.path): \(error.localizedDescription)")
    }
    let recorder = connect()
    defer { recorder.disconnect() }
    let crypto = DeviceCrypto()
    do {
        let entries = try fetchRecordings(recorder)
        let wanted = entries.filter { !alreadyDownloaded($0.fileId, in: directory) }
        print("\(entries.count) recordings on device, \(wanted.count) new")
        for entry in wanted {
            print("pulling \(entry.fileId) (\(displayDate.string(from: entry.startDate)), \(formatDuration(entry.estimatedDuration)))")
            try pull(entry, recorder: recorder, crypto: crypto, to: directory)
        }
    } catch {
        fail("\(error)")
    }

case "delete":
    let ids = arguments.dropFirst().compactMap { UInt32($0) }
    guard !ids.isEmpty, ids.count == arguments.count - 1 else { fail(usage) }
    let recorder = connect()
    defer { recorder.disconnect() }
    for fileId in ids {
        do {
            let reply = try recorder.request(Frames.deleteFile(fileId: fileId), type: 0x1A, id: 0x10, timeout: 10, "delete \(fileId)")
            if reply.status == 0 {
                print("deleted \(fileId)")
            } else {
                print("device refused to delete \(fileId) (status \(reply.status))")
            }
        } catch {
            fail("\(error)")
        }
    }

case "scan":
    do {
        try Recorder().scanAll(seconds: 10)
    } catch {
        fail("\(error)")
    }

default:
    print(usage)
    exit(2)
}
