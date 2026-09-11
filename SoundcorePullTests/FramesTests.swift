import XCTest
@testable import SoundcorePull

final class FramesTests: XCTestCase {
    func testEncodeDeviceInfo() {
        let frame = Frames.getDeviceInfo()
        XCTAssertEqual([UInt8](frame), [0x08, 0xEE, 0x00, 0x00, 0x00, 0x01, 0x01, 0x0A, 0x00, 0x02])
    }

    func testEncodeListFilesPage() {
        let frame = Frames.listFiles(page: 1)
        XCTAssertEqual([UInt8](frame), [0x08, 0xEE, 0x00, 0x00, 0x00, 0x1A, 0x0E, 0x0C, 0x00, 0x01, 0x00, 0x2B])
    }

    func testEncodeSyncTime() {
        let frame = [UInt8](Frames.syncTime(Date(timeIntervalSince1970: 1_789_159_433)))
        XCTAssertEqual(frame.prefix(9), [0x08, 0xEE, 0x00, 0x00, 0x00, 0x01, 0xA6, 0x0F, 0x00])
        XCTAssertEqual(Array(frame[9..<13]), [0x09, 0x68, 0xA4, 0x6A])
        XCTAssertEqual(frame.count, 15)
    }

    func testStartExportPayload() {
        let frame = Frames.startExport(fileId: 0x0102_0304)
        XCTAssertEqual(frame.count, 19)
        XCTAssertEqual([UInt8](frame[9..<18]), [0, 0, 0, 0, 0x04, 0x03, 0x02, 0x01, 0])
    }

    func testPacketBufferReassemblesFragmentsAndSkipsJunk() {
        var payload = Data([0x02, 0x00])                       // two entries
        payload += Frames.u32(1_700_000_000) + Frames.u32(30_000)
        payload += Frames.u32(1_700_000_100) + Frames.u32(0)
        payload += Frames.u32(0) + Frames.u32(0)                // current transfer timestamp + duration
        var frame = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1A, 0x0E])
        let total = UInt16(10 + payload.count)
        frame += Data([UInt8(total & 0xFF), UInt8(total >> 8)]) + payload
        frame.append(Frames.checksum(frame))

        var buffer = PacketBuffer()
        XCTAssertTrue(buffer.feed(Data([0xAA, 0xBB]) + frame.prefix(12)).isEmpty)
        let frames = buffer.feed(frame.dropFirst(12))
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].type, 0x1A)
        XCTAssertEqual(frames[0].id, 0x0E)
        XCTAssertEqual(frames[0].status, 1)

        let entries = RecordingEntry.parseList(frames[0].payload)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].fileId, 1_700_000_000)
        XCTAssertEqual(entries[0].estimatedDuration, 30)
    }

    func testBadChecksumIsDropped() {
        var frame = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x01, 0x01, 0x0A, 0x00, 0x00])
        frame[9] = 0x55
        var buffer = PacketBuffer()
        XCTAssertTrue(buffer.feed(frame).isEmpty)
    }
}
