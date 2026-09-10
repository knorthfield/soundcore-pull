import CommonCrypto
import CryptoKit
import Foundation

enum CryptoError: Error, CustomStringConvertible {
    case badHandshake
    case noSession
    case deviceRefused(UInt8)
    case badFileKey
    case noFileKey

    var description: String {
        switch self {
        case .badHandshake: return "ECDH handshake check failed"
        case .noSession: return "no decryption session"
        case .deviceRefused(let code): return "device refused export (error \(code))"
        case .badFileKey: return "file key check failed"
        case .noFileKey: return "no key for this file"
        }
    }
}

struct FileHead {
    let fileId: UInt32
    let fileSize: UInt32
}

/// ECDH P-256 session with the recorder, plus per-file AES-256-CTR keys.
final class DeviceCrypto {
    private let privateKey = P256.KeyAgreement.PrivateKey()
    private var sessionKey: Data?
    private var fileKeys: [UInt32: (key: Data, nonce: Data)] = [:]

    var hasSession: Bool { sessionKey != nil }

    var publicKey: Data { privateKey.publicKey.x963Representation }

    func completeHandshake(_ payload: Data) throws {
        guard payload.count >= 97 else { throw CryptoError.badHandshake }
        let p = Data(payload)
        let peer = try P256.KeyAgreement.PublicKey(x963Representation: p[0..<65])
        let shared = try privateKey.sharedSecretFromKeyAgreement(with: peer)
        let sharedBytes = shared.withUnsafeBytes { Data($0) }
        guard sharedBytes == p[65..<97] else { throw CryptoError.badHandshake }
        let derived = shared.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data([1, 2, 3]), sharedInfo: Data([1, 2, 3]), outputByteCount: 32)
        sessionKey = derived.withUnsafeBytes { Data($0) }
    }

    func prepareFile(_ payload: Data) throws -> FileHead {
        guard let sessionKey else { throw CryptoError.noSession }
        guard payload.count >= 87 else { throw CryptoError.badFileKey }
        let p = Data(payload)
        let head = FileHead(fileId: p.u32le(at: 0), fileSize: p.u32le(at: 4))
        let nonce = p[8..<24]
        let encryptedKey = p[24..<70]
        let sessionNonce = p[70..<86]
        let errorCode = p[86]
        if errorCode != 0 { throw CryptoError.deviceRefused(errorCode) }
        let plain = Self.aesCtr(encryptedKey, key: sessionKey, iv: Data(sessionNonce))
        guard plain.count >= 46, plain.prefix(14) == Data("soundcored3200".utf8) else { throw CryptoError.badFileKey }
        fileKeys[head.fileId] = (key: Data(plain[14..<46]), nonce: Data(nonce.prefix(12)))
        return head
    }

    func decryptChunk(fileId: UInt32, sequence: UInt32, data: Data) throws -> Data {
        guard let file = fileKeys[fileId] else { throw CryptoError.noFileKey }
        var iv = file.nonce
        let counter = sequence &* 10
        iv.append(contentsOf: [UInt8(counter >> 24), UInt8((counter >> 16) & 0xFF), UInt8((counter >> 8) & 0xFF), UInt8(counter & 0xFF)])
        return Self.aesCtr(data, key: file.key, iv: iv)
    }

    func clearFile(_ fileId: UInt32) { fileKeys[fileId] = nil }

    static func aesCtr(_ input: Data, key: Data, iv: Data) -> Data {
        var cryptor: CCCryptorRef?
        let status = key.withUnsafeBytes { keyPtr in
            iv.withUnsafeBytes { ivPtr in
                CCCryptorCreateWithMode(CCOperation(kCCDecrypt), CCMode(kCCModeCTR), CCAlgorithm(kCCAlgorithmAES),
                                        CCPadding(ccNoPadding), ivPtr.baseAddress, keyPtr.baseAddress, key.count,
                                        nil, 0, 0, CCModeOptions(kCCModeOptionCTR_BE), &cryptor)
            }
        }
        precondition(status == kCCSuccess, "AES-CTR init failed: \(status)")
        defer { CCCryptorRelease(cryptor) }
        var output = Data(count: input.count + kCCBlockSizeAES128)
        var moved = 0
        let update = input.withUnsafeBytes { inPtr in
            output.withUnsafeMutableBytes { outPtr in
                CCCryptorUpdate(cryptor, inPtr.baseAddress, input.count, outPtr.baseAddress, outPtr.count, &moved)
            }
        }
        precondition(update == kCCSuccess, "AES-CTR update failed: \(update)")
        return output.prefix(moved)
    }
}
