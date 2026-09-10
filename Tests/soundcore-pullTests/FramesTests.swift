import XCTest
@testable import soundcore_pull

final class FramesTests: XCTestCase {
    func testEncodeDeviceInfo() {
        let frame = Frames.getDeviceInfo()
        XCTAssertEqual([UInt8](frame), [0x08, 0xEE, 0x00, 0x00, 0x00, 0x01, 0x01, 0x0A, 0x00, 0x02])
    }

    func testEncodeListFilesPage() {
        let frame = Frames.listFiles(page: 1)
        XCTAssertEqual([UInt8](frame), [0x08, 0xEE, 0x00, 0x00, 0x00, 0x1B, 0x0E, 0x0C, 0x00, 0x01, 0x00, 0x2C])
    }

    func testStartExportPayload() {
        let frame = Frames.startExport(fileId: 0x0102_0304)
        XCTAssertEqual(frame.count, 19)
        XCTAssertEqual([UInt8](frame[9..<18]), [0, 0, 0, 0, 0x04, 0x03, 0x02, 0x01, 0])
    }

    func testPacketBufferReassemblesFragmentsAndSkipsJunk() {
        var payload = Data([0x02, 0x00])                       // two entries
        payload += Frames.u32(1_700_000_000) + Frames.u32(1_700_000_030) + Frames.u32(30_000)
        payload += Frames.u32(1_700_000_100) + Frames.u32(1_700_000_100) + Frames.u32(0)
        var frame = Data([0x09, 0xFF, 0x00, 0x00, 0x01, 0x1B, 0x0E])
        let total = UInt16(10 + payload.count)
        frame += Data([UInt8(total & 0xFF), UInt8(total >> 8)]) + payload
        frame.append(Frames.checksum(frame))

        var buffer = PacketBuffer()
        XCTAssertTrue(buffer.feed(Data([0xAA, 0xBB]) + frame.prefix(12)).isEmpty)
        let frames = buffer.feed(frame.dropFirst(12))
        XCTAssertEqual(frames.count, 1)
        XCTAssertEqual(frames[0].type, 0x1B)
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
