// Ed25519 keys for signing release archives that the in-app updater verifies.
//
//   swift script/update_signing.swift generate     create the private key (once) and print the public key
//   swift script/update_signing.swift public       print the public key of the existing private key
//   swift script/update_signing.swift sign FILE    write FILE.sig (base64 signature of FILE)
//
// The private key lives outside the repository (SHENG_UPDATE_KEY, or
// ~/Library/Application Support/xlle-release/shengjian-update-ed25519.key, mode 0600).
// Back it up: without it, installed copies cannot verify future updates.
import CryptoKit
import Foundation

func fail(_ message: String) -> Never { FileHandle.standardError.write(Data((message + "\n").utf8)); exit(1) }

let keyURL: URL = {
    if let path = ProcessInfo.processInfo.environment["SHENG_UPDATE_KEY"], !path.isEmpty { return URL(fileURLWithPath: path) }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/xlle-release/shengjian-update-ed25519.key")
}()

func loadKey() -> Curve25519.Signing.PrivateKey {
    guard let text = try? String(contentsOf: keyURL, encoding: .utf8),
          let raw = Data(base64Encoded: text.trimmingCharacters(in: .whitespacesAndNewlines)),
          let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: raw) else {
        fail("No signing key at \(keyURL.path). Run: swift script/update_signing.swift generate")
    }
    return key
}

let arguments = Array(CommandLine.arguments.dropFirst())
switch arguments.first {
case "generate":
    if FileManager.default.fileExists(atPath: keyURL.path) { fail("A key already exists at \(keyURL.path); refusing to overwrite it.") }
    try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    let key = Curve25519.Signing.PrivateKey()
    guard FileManager.default.createFile(atPath: keyURL.path, contents: Data(key.rawRepresentation.base64EncodedString().utf8), attributes: [.posixPermissions: 0o600]) else { fail("Could not write \(keyURL.path)") }
    print(key.publicKey.rawRepresentation.base64EncodedString())
case "public":
    print(loadKey().publicKey.rawRepresentation.base64EncodedString())
case "sign":
    guard arguments.count == 2 else { fail("usage: sign FILE") }
    let file = URL(fileURLWithPath: arguments[1])
    guard let data = try? Data(contentsOf: file) else { fail("Cannot read \(file.path)") }
    let signature = try loadKey().signature(for: data).base64EncodedString()
    try Data((signature + "\n").utf8).write(to: URL(fileURLWithPath: file.path + ".sig"), options: .atomic)
    print(file.path + ".sig")
default:
    fail("usage: swift script/update_signing.swift generate | public | sign FILE")
}
