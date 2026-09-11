import XCTest
@testable import SoundcorePull

final class LibraryTests: XCTestCase {
    func testFileIdFromName() {
        XCTAssertEqual(Library.fileId(fromName: "20260910-142205-1757514125.ogg"), 1_757_514_125)
        XCTAssertEqual(Library.fileId(fromName: ".20260910-142205-1757514125.ogg.icloud"), 1_757_514_125)
        XCTAssertNil(Library.fileId(fromName: ".20260910-142205-1757514125.ogg.part"))
        XCTAssertNil(Library.fileId(fromName: "notes.txt"))
    }

    func testSaveThenListed() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let library = Library(folder: folder)
        let entry = RecordingEntry(fileId: 1_757_514_125, sizeBytes: 10_000)
        try library.save(Data([1, 2, 3]), for: entry)
        XCTAssertEqual(library.downloadedIds(), [1_757_514_125])
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent(".\(library.fileName(for: entry)).part").path))
    }
}
