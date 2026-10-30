import Foundation

@main
@MainActor
struct ExtensionSectionJumpTests {
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

    static func main() {
        // Sections of 2, 1 and 3 start at 0, 2 and 3.
        let jump = ExtensionSectionJump(counts: [2, 1, 3])
        for (from, down) in [(0, 2), (1, 2), (2, 3), (3, 3), (4, 4), (5, 5)] {
            expect(jump.target(1, from: from) == down, "⌘↓ from \(from) lands on \(down)")
        }
        for (from, up) in [(0, 0), (1, 0), (2, 0), (3, 2), (4, 3), (5, 3)] {
            expect(jump.target(-1, from: from) == up, "⌘↑ from \(from) lands on \(up)")
        }
        expect(jump.target(1, from: 99) == 5, "⌘↓ from past the end clamps, then stays")
        expect(jump.target(-1, from: -4) == 0, "⌘↑ from below zero clamps, then stays")

        // A section drawn with nothing to land on is not a stop.
        let gapped = ExtensionSectionJump(counts: [2, 0, 2])
        expect(gapped.target(1, from: 0) == 2, "⌘↓ steps over an empty section")
        expect(gapped.target(-1, from: 2) == 0, "⌘↑ from a first row steps over an empty section")

        expect(ExtensionSectionJump(counts: []).target(1, from: 0) == 0, "no rows stays at zero")
        expect(ExtensionSectionJump(counts: [4]).target(1, from: 2) == 2, "one section: ⌘↓ stays")
        expect(ExtensionSectionJump(counts: [4]).target(-1, from: 2) == 0, "one section: ⌘↑ goes to 0")

        // Every shape against a brute-force read of each flat index's (section, offset).
        for a in 0...4 {
            for b in 0...4 {
                for c in 0...4 {
                    let counts = [a, b, c]
                    let index = ExtensionSectionJump(counts: counts)
                    let label = "[\(a),\(b),\(c)]"
                    var offsets: [Int] = []
                    for count in counts { offsets += Array(0..<count) }
                    let starts = offsets.indices.filter { offsets[$0] == 0 }
                    for from in offsets.indices {
                        expect(
                            index.target(1, from: from) == (starts.first { $0 > from } ?? from),
                            "\(label): ⌘↓ from \(from) lands on the next start")
                        expect(
                            index.target(-1, from: from) == (starts.last { $0 < from } ?? from),
                            "\(label): ⌘↑ from \(from) lands on the previous start")
                    }
                }
            }
        }

        print("\(passes) passed, \(failures) failed")
        if failures > 0 { exit(1) }
    }
}
