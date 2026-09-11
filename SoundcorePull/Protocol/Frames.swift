import Foundation

/// Wire protocol for the Soundcore Work (Anker/Feishu D3200) recorder.
/// TX: 08 EE 00 00 00 | type | id | len u16 LE | payload | checksum
/// RX: 09 FF 00 00 | status | type | id | len u16 LE | payload | checksum
enum Frames {
    static func checksum(_ bytes: Data) -> UInt8 {
        UInt8(truncatingIfNeeded: bytes.reduce(0) { $0 + Int($1) })
    }

    static func encode(type: UInt8, id: UInt8, payload: Data = Data()) -> Data {
        var frame = Data([0x08, 0xEE, 0x00, 0x00, 0x00, type, id])
        let total = UInt16(10 + payload.count)
        frame.append(UInt8(total & 0xFF))
        frame.append(UInt8(total >> 8))
        frame.append(payload)
        frame.append(checksum(frame))
        return frame
    }

    static func u16(_ value: UInt16) -> Data {
        Data([UInt8(value & 0xFF), UInt8(value >> 8)])
    }

    static func u32(_ value: UInt32) -> Data {
        Data([UInt8(value & 0xFF), UInt8((value >> 8) & 0xFF), UInt8((value >> 16) & 0xFF), UInt8(value >> 24)])
    }

    // Commands
    static func getDeviceInfo() -> Data { encode(type: 0x01, id: 0x01) }
    /// The plain list (0x1A). Firmware 03.36 answers the with-end-time variant (0x1B) with an empty payload.
    static func listFiles(page: UInt16) -> Data { encode(type: 0x1A, id: 0x0E, payload: u16(page)) }
    static func handshake(publicKey: Data) -> Data { encode(type: 0x2E, id: 0x01, payload: publicKey) }
    static func startExport(fileId: UInt32) -> Data {
        encode(type: 0x1A, id: 0x07, payload: u32(0) + u32(fileId) + Data([0x00]))
    }
    static func deleteFile(fileId: UInt32) -> Data { encode(type: 0x1A, id: 0x10, payload: u32(fileId)) }
}

struct Frame {
    let raw: Data
    let status: UInt8
    let type: UInt8
    let id: UInt8
    let payload: Data

    var hex: String { raw.map { String(format: "%02x", $0) }.joined(separator: " ") }
}

/// Reassembles complete RX frames from fragmented BLE notifications.
struct PacketBuffer {
    private var buffer = Data()

    mutating func feed(_ fragment: Data) -> [Frame] {
        buffer.append(fragment)
        var frames: [Frame] = []
        while buffer.count >= 10 {
            guard let start = findHeader() else {
                buffer.removeAll()
                break
            }
            if start > 0 { buffer.removeFirst(start) }
            if buffer.count < 10 { break }
            let total = Int(byte(7)) | (Int(byte(8)) << 8)
            if total < 10 {
                buffer.removeFirst(1)
                continue
            }
            if buffer.count < total { break }
            let raw = Data(buffer.prefix(total))
            buffer.removeFirst(total)
            guard Frames.checksum(raw.dropLast()) == raw[raw.count - 1] else { continue }
            frames.append(Frame(raw: raw, status: raw[4], type: raw[5], id: raw[6], payload: Data(raw[9..<(raw.count - 1)])))
        }
        return frames
    }

    /// Data slices keep their parent's indices, so index relative to startIndex.
    private func byte(_ offset: Int) -> UInt8 { buffer[buffer.startIndex + offset] }

    private func findHeader() -> Int? {
        guard buffer.count >= 4 else { return nil }
        for index in 0...(buffer.count - 4)
        where byte(index) == 0x09 && byte(index + 1) == 0xFF && byte(index + 2) == 0x00 && byte(index + 3) == 0x00 {
            return index
        }
        return nil
    }
}

extension Data {
    func u32le(at offset: Int) -> UInt32 {
        let b = self
        let i = b.startIndex + offset
        return UInt32(b[i]) | (UInt32(b[i + 1]) << 8) | (UInt32(b[i + 2]) << 16) | (UInt32(b[i + 3]) << 24)
    }

    func u16le(at offset: Int) -> UInt16 {
        let i = startIndex + offset
        return UInt16(self[i]) | (UInt16(self[i + 1]) << 8)
    }

    func ascii(_ range: Range<Int>) -> String {
        let slice = self[(startIndex + range.lowerBound)..<(startIndex + range.upperBound)]
        let trimmed = slice.prefix { $0 != 0 }
        return String(decoding: trimmed, as: UTF8.self).trimmingCharacters(in: .whitespaces)
    }
}

struct DeviceInfo {
    var batteryPercent: Int?
    var charging = false
    var firmware = ""
    var serial = ""
    var totalKB: UInt32 = 0
    var freeKB: UInt32 = 0
    var recording = false

    static func batteryPercent(_ raw: UInt8) -> Int {
        let value = Int(raw & 0x7F)
        return value <= 9 ? (value + 1) * 10 : min(value, 100)
    }

    static func parse(_ p: Data) -> DeviceInfo {
        var info = DeviceInfo()
        guard p.count >= 3 else { return info }
        info.batteryPercent = batteryPercent(p[p.startIndex + 1])
        info.charging = p[p.startIndex + 2] == 1
        var offset = 3
        if p.count >= offset + 5 { info.firmware = p.ascii(offset..<(offset + 5)); offset += 5 }
        if p.count >= offset + 16 { info.serial = p.ascii(offset..<(offset + 16)).lowercased(); offset += 16 }
        if p.count >= offset + 8 {
            info.totalKB = p.u32le(at: offset)
            info.freeKB = p.u32le(at: offset + 4)
            offset += 8
        }
        // box charging(1) box firmware(5) box battery(1) box mac(6) colour(1) auto-off(2) lights(2) recording(1)
        let recordingOffset = offset + 1 + 5 + 1 + 6 + 5
        if p.count > recordingOffset { info.recording = p[p.startIndex + recordingOffset] == 1 }
        return info
    }
}

struct RecordingEntry {
    let fileId: UInt32
    let sizeBytes: UInt32

    var startDate: Date { Date(timeIntervalSince1970: TimeInterval(fileId)) }

    /// Size tracks encoded milliseconds closely.
    var estimatedDuration: TimeInterval { TimeInterval(sizeBytes) / 1000 }

    static func parseList(_ p: Data) -> [RecordingEntry] {
        guard p.count >= 2 else { return [] }
        let count = Int(p.u16le(at: 0))
        var entries: [RecordingEntry] = []
        var offset = 2
        for _ in 0..<count where offset + 8 <= p.count {
            let entry = RecordingEntry(fileId: p.u32le(at: offset), sizeBytes: p.u32le(at: offset + 4))
            offset += 8
            if entry.sizeBytes > 0 { entries.append(entry) }
        }
        return entries
    }
}
