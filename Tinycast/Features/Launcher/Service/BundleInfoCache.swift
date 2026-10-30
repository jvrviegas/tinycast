import Foundation

/// What a scan reads from a bundle on disk, re-read only when its modification date moves.
struct BundleInfoCache: Sendable {
    struct Info: Sendable {
        let identifier: String?
        let shortVersion: String?
        let developmentRegion: String?
        let alternateNames: [String]
        let declaredName: String?
    }

    private struct Entry: Sendable {
        let modified: Date?
        let info: Info
        /// Preferred-language names first; `scan` takes the first as the display name.
        var names: [String]?
    }

    private let languages: [String]
    private let previous: [String: Entry]
    private var current: [String: Entry] = [:]

    init() {
        languages = []
        previous = [:]
    }

    /// Only what this pass asks about carries forward; a new system language drops it all.
    init(reusing cache: BundleInfoCache, languages: [String]) {
        self.languages = languages
        previous = cache.languages == languages ? cache.current : [:]
    }

    mutating func info(for url: URL) -> Info {
        entry(for: url).info
    }

    mutating func names(for url: URL, base: String) -> [String] {
        var entry = entry(for: url)
        if let names = entry.names { return names }
        let names = BundleLocalization.names(
            for: url, base: base, developmentRegion: entry.info.developmentRegion,
            languages: languages)
        entry.names = names
        current[url.path] = entry
        return names
    }

    /// Validated once per pass, so a second read in the same pass skips the `stat`.
    private mutating func entry(for url: URL) -> Entry {
        if let entry = current[url.path] { return entry }
        let modified = try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate
        let entry =
            if let cached = previous[url.path], cached.modified == modified {
                cached
            } else {
                Entry(modified: modified, info: Self.read(url), names: nil)
            }
        current[url.path] = entry
        return entry
    }

    /// Not `Bundle(url:)`: Foundation keeps every bundle it opens for the life of the process.
    private static func read(_ url: URL) -> Info {
        let info = CFBundleCopyInfoDictionaryForURL(url as CFURL) as? [String: Any] ?? [:]
        return Info(
            identifier: info["CFBundleIdentifier"] as? String,
            shortVersion: info["CFBundleShortVersionString"] as? String,
            developmentRegion: info["CFBundleDevelopmentRegion"] as? String,
            // Raw: a localized strings file can swap this array for a plain name.
            alternateNames: info["CFBundleAlternateNames"] as? [String] ?? [],
            declaredName: AppDisplayName.inInfo(info))
    }
}
