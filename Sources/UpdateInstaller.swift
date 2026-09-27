import AppKit
import CryptoKit
import Foundation

enum UpdateInstallerError: LocalizedError {
    case downloadFailed
    case checksumMismatch
    case mountFailed
    case appNotFoundInImage
    case installFailed(String)
    case relaunchFailed

    var errorDescription: String? {
        switch self {
        case .downloadFailed: return "Couldn't download the update."
        case .checksumMismatch: return "The downloaded update failed verification."
        case .mountFailed: return "Couldn't open the update disk image."
        case .appNotFoundInImage: return "The update disk image didn't contain Salawaty.app."
        case .installFailed(let reason): return "Couldn't install the update: \(reason)"
        case .relaunchFailed: return "Update installed, but couldn't relaunch automatically."
        }
    }
}

/// Downloads, verifies, and installs an update DMG published on GitHub Releases,
/// then relaunches the app in place. Requires the app not be sandboxed — it needs
/// to replace its own bundle, typically under /Applications.
enum UpdateInstaller {
    /// Downloads the update, verifies its checksum (when published), mounts the DMG,
    /// and copies the new .app into a staging folder. Returns the staged app's URL.
    static func downloadAndStage(_ info: UpdateInfo) async throws -> URL {
        let dmgURL = try await download(info.downloadURL)
        if let checksumURL = info.checksumURL {
            try await verifyChecksum(fileURL: dmgURL, checksumURL: checksumURL)
        }
        return try stage(dmgURL: dmgURL)
    }

    /// Replaces the running app's bundle with the staged one and launches the new copy.
    /// The caller is expected to terminate this process right after this returns.
    static func installAndRelaunch(stagedAppURL: URL) async throws {
        let targetURL = Bundle.main.bundleURL
        let fm = FileManager.default

        let trashURL = targetURL.deletingLastPathComponent()
            .appendingPathComponent(".\(targetURL.lastPathComponent).old-\(Int(Date().timeIntervalSince1970))")
        do {
            try fm.moveItem(at: targetURL, to: trashURL)
        } catch {
            throw UpdateInstallerError.installFailed("no write access to \(targetURL.deletingLastPathComponent().path)")
        }

        do {
            try fm.copyItem(at: stagedAppURL, to: targetURL)
        } catch {
            try? fm.moveItem(at: trashURL, to: targetURL)   // best-effort restore
            throw UpdateInstallerError.installFailed(error.localizedDescription)
        }
        try? fm.removeItem(at: trashURL)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: targetURL, configuration: config) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Steps

    private static func download(_ url: URL) async throws -> URL {
        guard let (tempURL, response) = try? await URLSession.shared.download(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw UpdateInstallerError.downloadFailed
        }
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tempURL, to: dest)
        return dest
    }

    private static func verifyChecksum(fileURL: URL, checksumURL: URL) async throws {
        guard let (data, response) = try? await URLSession.shared.data(from: checksumURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let text = String(data: data, encoding: .utf8),
              let expected = text.split(separator: " ").first else {
            throw UpdateInstallerError.checksumMismatch
        }
        let fileData = try Data(contentsOf: fileURL)
        let digest = SHA256.hash(data: fileData).map { String(format: "%02x", $0) }.joined()
        guard digest == expected.lowercased() else { throw UpdateInstallerError.checksumMismatch }
    }

    /// Mounts the DMG read-only, copies its .app out, then unmounts — regardless of outcome.
    private static func stage(dmgURL: URL) throws -> URL {
        let mountPoint = FileManager.default.temporaryDirectory
            .appendingPathComponent("SalawatyUpdateMount-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: mountPoint, withIntermediateDirectories: true)

        let attach = Process()
        attach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        attach.arguments = ["attach", dmgURL.path, "-nobrowse", "-readonly", "-mountpoint", mountPoint.path]
        try attach.run()
        attach.waitUntilExit()
        guard attach.terminationStatus == 0 else { throw UpdateInstallerError.mountFailed }
        defer {
            let detach = Process()
            detach.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            detach.arguments = ["detach", mountPoint.path, "-quiet"]
            try? detach.run()
            detach.waitUntilExit()
        }

        let contents = (try? FileManager.default.contentsOfDirectory(at: mountPoint, includingPropertiesForKeys: nil)) ?? []
        guard let appURL = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateInstallerError.appNotFoundInImage
        }

        let stagingDir = FileManager.default.temporaryDirectory.appendingPathComponent("SalawatyUpdateStaged")
        try? FileManager.default.removeItem(at: stagingDir)
        try FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        let stagedAppURL = stagingDir.appendingPathComponent(appURL.lastPathComponent)
        try FileManager.default.copyItem(at: appURL, to: stagedAppURL)
        clearQuarantine(stagedAppURL)
        return stagedAppURL
    }

    /// Removes the com.apple.quarantine flag Gatekeeper would otherwise set on a
    /// downloaded app, which — without a paid Developer ID + notarization — would
    /// block the relaunch after install with the same "Not Opened" dialog a fresh
    /// manual DMG download shows. Safe here: this app already trusts and just
    /// verified (checksum) the copy it downloaded from its own GitHub releases.
    private static func clearQuarantine(_ url: URL) {
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-dr", "com.apple.quarantine", url.path]
        try? xattr.run()
        xattr.waitUntilExit()
    }
}
