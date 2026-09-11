import Foundation

/// Wraps the recorder's raw 160-byte Opus frames (48 kHz mono, 20 ms) in an Ogg container.
enum OggOpus {
    static let frameSize = 160
    static let samplesPerFrame: UInt64 = 960
    static let sampleRate: UInt32 = 48000
    private static let serial: UInt32 = 0x4152_4B52

    static func mux(_ raw: Data) -> Data {
        var frames: [Data] = []
        var offset = 0
        while offset < raw.count {
            var frame = Data(raw[(raw.startIndex + offset)..<min(raw.startIndex + offset + frameSize, raw.endIndex)])
            while let last = frame.last, last == 0 { frame.removeLast() }
            frames.append(frame.isEmpty ? Data([0]) : frame)
            offset += frameSize
        }

        var head = Data("OpusHead".utf8)
        head.append(contentsOf: [1, 1])                       // version, channel count
        head.append(contentsOf: [0x00, 0x0F])                 // pre-skip 3840 LE
        head.append(Frames.u32(sampleRate))
        head.append(contentsOf: [0, 0])                       // output gain
        head.append(0)                                        // channel mapping family

        let vendor = Data("soundcore-pull".utf8)
        var tags = Data("OpusTags".utf8)
        tags.append(Frames.u32(UInt32(vendor.count)))
        tags.append(vendor)
        tags.append(Frames.u32(0))

        var output = page([head], sequence: 0, granule: 0, flags: 0x02)
        output.append(page([tags], sequence: 1, granule: 0, flags: 0))
        var granule: UInt64 = 0
        var sequence: UInt32 = 2
        var start = 0
        while start < frames.count {
            let batch = Array(frames[start..<min(start + 50, frames.count)])
            granule += UInt64(batch.count) * samplesPerFrame
            let isLast = start + 50 >= frames.count
            output.append(page(batch, sequence: sequence, granule: granule, flags: isLast ? 0x04 : 0))
            sequence += 1
            start += 50
        }
        return output
    }

    static func page(_ packets: [Data], sequence: UInt32, granule: UInt64, flags: UInt8) -> Data {
        var segments: [UInt8] = []
        for packet in packets {
            var remaining = packet.count
            while remaining >= 255 { segments.append(255); remaining -= 255 }
            segments.append(UInt8(remaining))
        }
        var header = Data("OggS".utf8)
        header.append(0)
        header.append(flags)
        for shift in stride(from: 0, to: 64, by: 8) { header.append(UInt8((granule >> UInt64(shift)) & 0xFF)) }
        header.append(Frames.u32(serial))
        header.append(Frames.u32(sequence))
        header.append(Frames.u32(0))                          // CRC placeholder
        header.append(UInt8(segments.count))
        header.append(contentsOf: segments)
        var pageData = header
        for packet in packets { pageData.append(packet) }
        let crc = crc32(pageData)
        pageData.replaceSubrange(22..<26, with: Frames.u32(crc))
        return pageData
    }

    /// Ogg CRC: polynomial 0x04C11DB7, no reflection, initial value 0, no final XOR.
    static func crc32(_ bytes: Data) -> UInt32 {
        var crc: UInt32 = 0
        for byte in bytes {
            crc ^= UInt32(byte) << 24
            for _ in 0..<8 {
                crc = (crc & 0x8000_0000) != 0 ? (crc << 1) ^ 0x04C1_1DB7 : crc << 1
            }
        }
        return crc
    }
}
