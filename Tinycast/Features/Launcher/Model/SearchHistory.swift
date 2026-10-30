import Foundation

/// The searches the launcher ran a result from, newest first, so ↑ can bring one back.
@MainActor
@Observable
final class SearchHistory {
    nonisolated static let limit = 50
    /// Past this a query is pasted text, not a search worth recalling.
    nonisolated static let queryLimit = 256

    private let fileURL: URL
    private(set) var queries: [String]

    /// The in-flight persist, awaited by the next one so a burst can't land out of order.
    @ObservationIgnored private var writeTask: Task<Void, Never>?

    init(fileURL: URL) {
        self.fileURL = fileURL
        queries =
            (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
    }

    var isEmpty: Bool { queries.isEmpty }

    /// Awaits the pending persist. The launcher never needs it; reading the file back does.
    func flush() async {
        await writeTask?.value
    }

    func record(_ query: String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count <= Self.queryLimit else { return }
        queries.removeAll { $0 == query }
        queries.insert(query, at: 0)
        queries = Array(queries.prefix(Self.limit))
        didMutate()
    }

    /// The search ↑ brings back: the newest from an empty field, else the one just older than it.
    func older(than current: String) -> String? {
        let current = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty { return queries.first }
        guard let index = queries.firstIndex(of: current) else { return nil }
        return queries.indices.contains(index + 1) ? queries[index + 1] : nil
    }

    func clear() {
        guard !queries.isEmpty else { return }
        queries = []
        didMutate()
    }

    private func didMutate() {
        // Off-main: this lands on ↵, in front of the launch. Chained, so writes stay ordered.
        let snapshot = queries
        let fileURL = fileURL
        let previous = writeTask
        writeTask = Task.detached(priority: .utility) {
            await previous?.value
            if snapshot.isEmpty {
                try? FileManager.default.removeItem(at: fileURL)
            } else if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: fileURL, options: .atomic)
            }
        }
    }
}
