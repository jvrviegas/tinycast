import Foundation

@main
@MainActor
struct SearchHistoryTests {
    static var failures = 0
    static var passes = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            passes += 1
        } else {
            failures += 1
            print("FAIL: \(message)")
        }
    }

    static func scratchFile() -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("search-history-test-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("search-history.json")
    }

    static func main() async {
        // Newest first, trimmed, and a repeat moves to the front instead of appearing twice.
        let history = SearchHistory(fileURL: scratchFile())
        expect(history.isEmpty, "a fresh history is empty")
        history.record("safari")
        history.record("  12*4  ")
        history.record("notes")
        expect(history.queries == ["notes", "12*4", "safari"], "newest first, trimmed")
        history.record("safari")
        expect(history.queries == ["safari", "notes", "12*4"], "a repeat moves to the front")
        history.record("Safari")
        expect(history.queries.count == 4, "a different case is a different search")

        // Nothing worth recalling is kept.
        let before = history.queries
        history.record("")
        history.record("   \n\t ")
        history.record(String(repeating: "x", count: SearchHistory.queryLimit + 1))
        expect(history.queries == before, "empty, blank and pasted-paragraph queries are ignored")
        history.record(String(repeating: "y", count: SearchHistory.queryLimit))
        expect(history.queries.first?.count == SearchHistory.queryLimit, "a query at the limit is kept")

        // The newest 50 survive.
        let bounded = SearchHistory(fileURL: scratchFile())
        for number in 1...(SearchHistory.limit + 10) { bounded.record("q\(number)") }
        expect(bounded.queries.count == SearchHistory.limit, "the history is bounded")
        expect(bounded.queries.first == "q\(SearchHistory.limit + 10)", "the newest is kept")
        expect(bounded.queries.last == "q11", "the oldest ten are dropped")

        // ↑ from the field: the newest from empty, then one older each time, then nothing.
        let walk = SearchHistory(fileURL: scratchFile())
        expect(walk.older(than: "") == nil, "no history, nothing to bring back")
        for query in ["a", "b", "c"] { walk.record(query) }
        expect(walk.older(than: "") == "c", "an empty field brings back the newest")
        expect(walk.older(than: "  ") == "c", "a blank field counts as empty")
        expect(walk.older(than: "c") == "b", "the next ↑ brings back the one before")
        expect(walk.older(than: "b") == "a", "and the one before that")
        expect(walk.older(than: "a") == nil, "the oldest has nothing older")
        expect(walk.older(than: "ca") == nil, "typed text that is no search ends the walk")

        // On disk: a new instance reads what the last one wrote, in order.
        let file = scratchFile()
        let writer = SearchHistory(fileURL: file)
        for query in ["one", "two", "three"] { writer.record(query) }
        await writer.flush()
        let reader = SearchHistory(fileURL: file)
        expect(reader.queries == ["three", "two", "one"], "the history survives a relaunch")

        // A bad file reads as empty and is replaced by the next search.
        let broken = scratchFile()
        try? Data("not json".utf8).write(to: broken)
        let recovering = SearchHistory(fileURL: broken)
        expect(recovering.isEmpty, "an unreadable file reads as empty")
        recovering.record("fresh")
        await recovering.flush()
        expect(SearchHistory(fileURL: broken).queries == ["fresh"], "the next search replaces it")
        expect(SearchHistory(fileURL: scratchFile()).isEmpty, "a missing file reads as empty")

        // Clearing empties the list and removes the file, even right after a write.
        let clearing = scratchFile()
        let store = SearchHistory(fileURL: clearing)
        store.record("gone")
        store.clear()
        await store.flush()
        expect(store.isEmpty, "clear empties the history")
        expect(!FileManager.default.fileExists(atPath: clearing.path), "clear removes the file")
        expect(SearchHistory(fileURL: clearing).isEmpty, "a cleared history stays cleared")
        store.record("again")
        await store.flush()
        expect(SearchHistory(fileURL: clearing).queries == ["again"], "searching after a clear works")

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
