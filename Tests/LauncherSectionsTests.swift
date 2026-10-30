import Foundation

@main
@MainActor
struct LauncherSectionsTests {
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

    /// The kind order `LauncherList` once spelled out, as plain numbers.
    static let publicationOrder = Array(0..<14)

    typealias Named = [(name: String, count: Int)]

    /// `LauncherList.rows` as it stood: a dictionary regroup of the results past the matches, walked
    /// in a fixed kind order. It is the proof that the plan draws the same sections.
    static func legacy(
        hasCard: Bool, favorites: Int, meetings: Int, suggestions: Int, matches: Int, rest: [Int],
        files: Int, fallbacks: Int
    ) -> Named {
        var sections: Named = []
        if hasCard { sections.append(("card", 1)) }
        if favorites > 0 { sections.append(("favorites", favorites)) }
        if meetings > 0 { sections.append(("meetings", meetings)) }
        if suggestions > 0 { sections.append(("suggestions", suggestions)) }
        if matches > 0 { sections.append(("results", matches)) }
        var grouped: [Int: Int] = [:]
        for group in rest { grouped[group, default: 0] += 1 }
        for group in publicationOrder {
            if let count = grouped[group], count > 0 { sections.append(("group\(group)", count)) }
        }
        if files > 0 { sections.append(("files", files)) }
        if fallbacks > 0 { sections.append(("fallbacks", fallbacks)) }
        return sections
    }

    static func named(_ plan: LauncherSections<Int>) -> Named {
        plan.sections.map { section in
            switch section.kind {
            case .card: ("card", section.count)
            case .favorites: ("favorites", section.count)
            case .meetings: ("meetings", section.count)
            case .suggestions: ("suggestions", section.count)
            case .results: ("results", section.count)
            case .group(let group): ("group\(group)", section.count)
            case .files: ("files", section.count)
            case .fallbacks: ("fallbacks", section.count)
            }
        }
    }

    static func same(_ a: Named, _ b: Named) -> Bool {
        a.count == b.count && zip(a, b).allSatisfy { $0.name == $1.name && $0.count == $1.count }
    }

    /// Deterministic, so a failure names the same case on every run.
    struct Generator {
        var state: UInt64
        mutating func next(_ bound: Int) -> Int {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Int((state >> 33) % UInt64(bound))
        }
    }

    static func main() {
        let none = LauncherSections<Int>(
            hasCard: false, favorites: 0, meetings: 0, suggestions: 0, matches: 0, rest: [], files: 0,
            fallbacks: 0)
        expect(none.sections.isEmpty, "nothing listed means no sections")
        expect(none.counts.isEmpty, "and no counts")

        let card = LauncherSections<Int>(
            hasCard: true, favorites: 0, meetings: 0, suggestions: 0, matches: 0, rest: [], files: 0,
            fallbacks: 0)
        expect(same(named(card), [("card", 1)]), "a lead card is a section of one row")

        // The empty-query launcher: favorites, suggestions, then one section per kind.
        let empty = LauncherSections<Int>(
            hasCard: false, favorites: 3, meetings: 0, suggestions: 2, matches: 0,
            rest: [1, 1, 1, 4, 4, 9], files: 0, fallbacks: 0)
        expect(
            same(
                named(empty),
                [("favorites", 3), ("suggestions", 2), ("group1", 3), ("group4", 2), ("group9", 1)]),
            "favorites, suggestions and a section per kind, in that order")
        expect(empty.counts == [3, 2, 3, 2, 1], "counts are the rows in each section")

        // A typed query: matches, then the rest, then files and the fallback section.
        let typed = LauncherSections<Int>(
            hasCard: true, favorites: 0, meetings: 0, suggestions: 0, matches: 4, rest: [2, 2],
            files: 3, fallbacks: 2)
        expect(
            same(named(typed), [("card", 1), ("results", 4), ("group2", 2), ("files", 3), ("fallbacks", 2)]),
            "a card, the matches, the rest, files and fallbacks")

        // The flat order wins: selection indexes it, so a plan never reorders to fit a fixed list.
        let outOfOrder = LauncherSections<Int>(
            hasCard: false, favorites: 0, meetings: 0, suggestions: 0, matches: 0, rest: [3, 3, 1, 1],
            files: 0, fallbacks: 0)
        expect(same(named(outOfOrder), [("group3", 2), ("group1", 2)]), "sections follow the rows as given")
        let split = LauncherSections<Int>(
            hasCard: false, favorites: 0, meetings: 0, suggestions: 0, matches: 0, rest: [1, 2, 1],
            files: 0, fallbacks: 0)
        expect(
            same(named(split), [("group1", 1), ("group2", 1), ("group1", 1)]),
            "a kind that returns after another starts a new section instead of being pulled back")

        // The proof: on every input the shipped order allows, the plan draws what the list drew.
        var generator = Generator(state: 20_251_030)
        for run in 0..<20_000 {
            let hasCard = generator.next(2) == 1
            let favorites = generator.next(4)
            let meetings = generator.next(3)
            let suggestions = generator.next(4)
            let matches = generator.next(5)
            var rest: [Int] = []
            for group in publicationOrder where generator.next(5) < 2 {
                rest += Array(repeating: group, count: 1 + generator.next(3))
            }
            let files = generator.next(4)
            let fallbacks = generator.next(3)
            let plan = LauncherSections(
                hasCard: hasCard, favorites: favorites, meetings: meetings, suggestions: suggestions,
                matches: matches, rest: rest, files: files, fallbacks: fallbacks)
            let total =
                (hasCard ? 1 : 0) + favorites + meetings + suggestions + matches + rest.count + files
                + fallbacks
            expect(
                same(
                    named(plan),
                    legacy(
                        hasCard: hasCard, favorites: favorites, meetings: meetings,
                        suggestions: suggestions, matches: matches, rest: rest, files: files,
                        fallbacks: fallbacks)),
                "run \(run): the plan matches the list's own grouping")
            expect(plan.counts.reduce(0, +) == total, "run \(run): every row is in exactly one section")
            expect(!plan.counts.contains(0), "run \(run): no section is empty")
        }

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
