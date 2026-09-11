import Foundation

/// The folder recordings are saved to, and what is already there.
struct Library {
    let folder: URL

    static let iCloud = Library(folder: FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Soundcore Work"))

    private static let nameDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    func fileName(for entry: RecordingEntry) -> String {
        "\(Self.nameDate.string(from: entry.startDate))-\(entry.fileId).ogg"
    }

    /// File ids present in the folder. iCloud lists evicted files as `.<name>.icloud`.
    func downloadedIds() -> Set<UInt32> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return Set(names.compactMap(Self.fileId(fromName:)))
    }

    static func fileId(fromName name: String) -> UInt32? {
        var base = name
        if base.hasPrefix(".") && base.hasSuffix(".icloud") { base = String(base.dropFirst().dropLast(7)) }
        guard base.hasSuffix(".ogg"), let dash = base.lastIndex(of: "-") else { return nil }
        return UInt32(base[base.index(after: dash)..<base.index(base.endIndex, offsetBy: -4)])
    }

    /// Writes to a temp file first so iCloud never uploads a partial recording.
    func save(_ ogg: Data, for entry: RecordingEntry) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = fileName(for: entry)
        let temp = folder.appendingPathComponent(".\(name).part")
        try ogg.write(to: temp)
        _ = try FileManager.default.replaceItemAt(folder.appendingPathComponent(name), withItemAt: temp)
    }
}
