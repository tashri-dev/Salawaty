import Foundation

/// x.y.z, comparable field by field. Extra/missing fields are treated as 0.
struct SemanticVersion: Comparable {
    let components: [Int]

    init?(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        let parts = s.split(separator: "-", maxSplits: 1).first.map(String.init) ?? s // drop "-beta" etc.
        let nums = parts.split(separator: ".").map { Int($0) }
        guard !nums.isEmpty, !nums.contains(where: { $0 == nil }) else { return nil }
        components = nums.map { $0! }
    }

    private func padded(to count: Int) -> [Int] {
        components + Array(repeating: 0, count: max(0, count - components.count))
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let n = max(lhs.components.count, rhs.components.count)
        return lhs.padded(to: n).lexicographicallyPrecedes(rhs.padded(to: n))
    }

    static func == (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let n = max(lhs.components.count, rhs.components.count)
        return lhs.padded(to: n) == rhs.padded(to: n)
    }
}

enum UpdateStage: Equatable {
    case idle
    case downloading
    case readyToInstall
    case failed(String)
}

struct UpdateInfo: Equatable {
    let version: String   // e.g. "1.2.0"
    let url: URL           // the release's web page, for manual fallback
    let downloadURL: URL   // the .dmg asset
    let checksumURL: URL?  // the .dmg.sha256 asset, if published
}

enum UpdateChecker {
    static let owner = "tashri-dev"
    static let repo = "Salawaty"

    private struct GitHubRelease: Decodable {
        let tag_name: String
        let html_url: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browser_download_url: String
    }

    /// Compares the latest published GitHub release against the running app's version.
    /// Returns nil if up to date, unreachable, the release is a draft/prerelease,
    /// or it has no .dmg asset to download.
    static func checkForUpdate() async -> UpdateInfo? {
        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let release = try? JSONDecoder().decode(GitHubRelease.self, from: data),
              !release.draft, !release.prerelease,
              let latest = SemanticVersion(release.tag_name),
              let current = currentVersion,
              latest > current,
              let releaseURL = URL(string: release.html_url),
              let dmgAsset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
              let downloadURL = URL(string: dmgAsset.browser_download_url) else { return nil }

        let checksumURL = release.assets
            .first { $0.name.hasSuffix(".dmg.sha256") }
            .flatMap { URL(string: $0.browser_download_url) }

        return UpdateInfo(version: release.tag_name, url: releaseURL,
                          downloadURL: downloadURL, checksumURL: checksumURL)
    }

    static var currentVersion: SemanticVersion? {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).flatMap(SemanticVersion.init)
    }

    static var currentVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}
