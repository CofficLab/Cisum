import Foundation
import CisumUIComponents
import LumiUI

public struct BookLikeItem: Hashable, Identifiable {
    public let url: URL
    public let title: String

    public var id: String { url.absoluteString }
}

public enum BookLikeStore {
    private static let likedBooksKey = "BookLikePlugin.likedBooks"

    public static func likedBooks(defaults: UserDefaults = .standard) -> [BookLikeItem] {
        let storedBooks = defaults.dictionary(forKey: likedBooksKey) as? [String: String] ?? [:]

        return storedBooks.compactMap { rawURL, title in
            guard let url = storedURL(from: rawURL) else { return nil }
            return BookLikeItem(url: url, title: title)
        }
        .sorted {
            $0.title.localizedStandardCompare($1.title) == .orderedAscending
        }
    }

    public static func setLiked(_ liked: Bool, url: URL, defaults: UserDefaults = .standard) {
        var storedBooks = defaults.dictionary(forKey: likedBooksKey) as? [String: String] ?? [:]
        let key = url.absoluteString
        removeEntriesRepresenting(url, from: &storedBooks)

        if liked {
            storedBooks[key] = displayTitle(for: url)
        }

        defaults.set(storedBooks, forKey: likedBooksKey)
    }

    public static func removeAll(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: likedBooksKey)
    }

    private static func displayTitle(for url: URL) -> String {
        let title = url.lastPathComponent
        return title.isEmpty ? url.absoluteString : title
    }

    static func storedURL(from rawURL: String) -> URL? {
        let rawURL = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rawURL.isEmpty else { return nil }
        if let url = URL(string: rawURL), url.scheme != nil {
            return url
        }

        guard rawURL.hasPrefix("/") else { return nil }
        return URL(fileURLWithPath: rawURL)
    }

    private static func removeEntriesRepresenting(_ url: URL, from storedBooks: inout [String: String]) {
        for key in storedBooks.keys {
            guard let storedURL = storedURL(from: key), representsSameFile(storedURL, url) else { continue }
            storedBooks.removeValue(forKey: key)
        }
    }

    private static func representsSameFile(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.isSameFileLocation(as: rhs)
    }
}
