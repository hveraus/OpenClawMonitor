import Foundation
import CryptoKit

/// Persistent Ed25519 device identity used for gateway challenge-response auth.
/// The key pair is generated once and stored in Application Support.
final class DeviceIdentity {

    static let shared = DeviceIdentity()

    let privateKey: Curve25519.Signing.PrivateKey
    /// SHA-256 hex fingerprint of the raw 32-byte public key.
    let deviceId: String
    /// Base64URL-encoded raw 32-byte Ed25519 public key.
    let publicKeyBase64URL: String

    private init() {
        if let loaded = DeviceIdentity.loadFromDisk() {
            privateKey = loaded
        } else {
            privateKey = Curve25519.Signing.PrivateKey()
            DeviceIdentity.saveToDisk(privateKey)
        }
        let pubRaw = privateKey.publicKey.rawRepresentation
        deviceId       = SHA256.hash(data: pubRaw).map { String(format: "%02x", $0) }.joined()
        publicKeyBase64URL = pubRaw.base64URLString
    }

    // MARK: - Signing

    /// Build and sign the canonical payload. Returns (signature, signedAt) or nil on error.
    func sign(nonce: String, token: String, role: String, scopes: [String]) -> (sig: String, signedAt: Int64)? {
        let signedAt   = Int64(Date().timeIntervalSince1970 * 1000)
        let clientId   = "openclaw-macos"
        let clientMode = "ui"
        let scopesStr  = scopes.joined(separator: ",")
        // v2 format: no platform/deviceFamily — avoids ambiguity
        let payload = "v2|\(deviceId)|\(clientId)|\(clientMode)|\(role)|\(scopesStr)|\(signedAt)|\(token)|\(nonce)"
        gwLog("[DeviceIdentity] signing payload: \(payload)")
        guard let sig = try? privateKey.signature(for: Data(payload.utf8)) else { return nil }
        return (sig.base64URLString, signedAt)
    }

    // MARK: - Persistence

    private static let identityURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("OpenClawMonitor/device-identity.json")
    }()

    private static func loadFromDisk() -> Curve25519.Signing.PrivateKey? {
        guard let data    = try? Data(contentsOf: identityURL),
              let json    = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let privHex = json["privateKey"],
              let privData = Data(hexEncoded: privHex),
              let key     = try? Curve25519.Signing.PrivateKey(rawRepresentation: privData)
        else { return nil }
        return key
    }

    private static func saveToDisk(_ key: Curve25519.Signing.PrivateKey) {
        let json: [String: String] = ["privateKey": key.rawRepresentation.hexString]
        guard let data = try? JSONSerialization.data(withJSONObject: json) else { return }
        try? FileManager.default.createDirectory(at: identityURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: identityURL, options: .atomic)
    }
}

// MARK: - Data helpers

extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }

    var base64URLString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    init?(hexEncoded: String) {
        guard hexEncoded.count.isMultiple(of: 2) else { return nil }
        var bytes = [UInt8]()
        bytes.reserveCapacity(hexEncoded.count / 2)
        var idx = hexEncoded.startIndex
        while idx < hexEncoded.endIndex {
            let next = hexEncoded.index(idx, offsetBy: 2)
            guard let byte = UInt8(hexEncoded[idx..<next], radix: 16) else { return nil }
            bytes.append(byte)
            idx = next
        }
        self = Data(bytes)
    }
}
