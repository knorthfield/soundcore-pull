import XCTest
@testable import SoundcorePull

final class OggOpusTests: XCTestCase {
    func testCrc32KnownVector() {
        // Ogg CRC of "123456789" (poly 0x04C11DB7, no reflection, init 0, no xorout) is 0x89A1897F.
        XCTAssertEqual(OggOpus.crc32(Data("123456789".utf8)), 0x89A1_897F)
    }

    func testMuxLayout() {
        let raw = Data(repeating: 0x7F, count: 160 * 120)
        let ogg = OggOpus.mux(raw)
        XCTAssertEqual(ogg.prefix(4), Data("OggS".utf8))
        XCTAssertEqual(ogg[5], 0x02)                          // BOS on the OpusHead page
        XCTAssertEqual(ogg[27], 19)                           // single 19-byte OpusHead segment
        XCTAssertEqual(Data(ogg[28..<36]), Data("OpusHead".utf8))
        // 120 frames -> pages of 50, 50, 20 plus the two header pages
        let pageCount = ogg.indices.filter { $0 + 4 <= ogg.count && ogg[$0..<($0 + 4)] == Data("OggS".utf8) }.count
        XCTAssertEqual(pageCount, 5)
        XCTAssertEqual(ogg.last, 0x7F)
    }

    func testTrailingZerosStripped() {
        var raw = Data(repeating: 0x11, count: 100)
        raw += Data(repeating: 0, count: 60)
        let ogg = OggOpus.mux(raw)
        // last page: 27-byte header + 1 segment table byte + 100 bytes of packet
        XCTAssertEqual(ogg.suffix(101).first, 100)
        XCTAssertEqual(ogg.suffix(100), Data(repeating: 0x11, count: 100))
    }
}
