import XCTest
@testable import soundcore_pull

final class DeviceCryptoTests: XCTestCase {
    func hex(_ string: String) -> Data {
        var data = Data()
        var index = string.startIndex
        while index < string.endIndex {
            let next = string.index(index, offsetBy: 2)
            data.append(UInt8(string[index..<next], radix: 16)!)
            index = next
        }
        return data
    }

    func testAesCtrNistVector() {
        // NIST SP 800-38A F.5.5, AES-256 CTR, first block. CTR decrypt equals encrypt.
        let key = hex("603deb1015ca71be2b73aef0857d77811f352c073b6108d72d9810a30914dff4")
        let iv = hex("f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff")
        let ciphertext = hex("601ec313775789a5b7a7f504bbf3d228")
        XCTAssertEqual(DeviceCrypto.aesCtr(ciphertext, key: key, iv: iv), hex("6bc1bee22e409f96e93d7e117393172a"))
    }

    func testPublicKeyIsUncompressedP256() {
        let key = DeviceCrypto().publicKey
        XCTAssertEqual(key.count, 65)
        XCTAssertEqual(key.first, 0x04)
    }
}
