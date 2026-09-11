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

    func testMergeRecorderAndICloud() {
        let onRecorder = [RecordingEntry(fileId: 100, sizeBytes: 1_000), RecordingEntry(fileId: 300, sizeBytes: 3_000)]
        let rows = RecordingRow.merge(onRecorder: onRecorder, downloaded: [200, 300])
        XCTAssertEqual(rows.map(\.fileId), [300, 200, 100])
        XCTAssertEqual(rows.map(\.statusText), ["On recorder · Downloaded", "Downloaded", "On recorder"])
        XCTAssertNil(rows[1].onRecorder)
        XCTAssertEqual(rows[2].onRecorder?.sizeBytes, 1_000)
    }
}
