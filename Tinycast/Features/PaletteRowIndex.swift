import Foundation

/// What a flat selection index resolves to. Section headers aren't selectable and take no index.
enum PaletteRow: Equatable {
    case calculator
    case element(section: Int, offset: Int)
}

/// A screen's visible row order: the calculator card at index 0 when present, then each section.
struct PaletteRowIndex: Equatable {
    let hasCalculator: Bool
    let sectionCounts: [Int]

    init(hasCalculator: Bool = false, sectionCounts: [Int]) {
        self.hasCalculator = hasCalculator
        self.sectionCounts = sectionCounts
    }

    var count: Int { (hasCalculator ? 1 : 0) + sectionCounts.reduce(0, +) }

    func clamped(_ selection: Int) -> Int {
        count == 0 ? 0 : min(max(selection, 0), count - 1)
    }

    func row(at index: Int) -> PaletteRow? {
        guard index >= 0, index < count else { return nil }
        if hasCalculator, index == 0 { return .calculator }
        var offset = hasCalculator ? index - 1 : index
        for (section, sectionCount) in sectionCounts.enumerated() {
            if offset < sectionCount { return .element(section: section, offset: offset) }
            offset -= sectionCount
        }
        return nil
    }

    /// ⌘↓ lands on the next section's first row; ⌘↑ on this one's, or the previous one's from it.
    func sectionJump(_ delta: Int, from index: Int) -> Int {
        guard count > 0 else { return 0 }
        let selection = clamped(index)
        var starts = hasCalculator ? [0] : []
        var next = hasCalculator ? 1 : 0
        for sectionCount in sectionCounts where sectionCount > 0 {
            starts.append(next)
            next += sectionCount
        }
        let target = delta > 0 ? starts.first { $0 > selection } : starts.last { $0 < selection }
        return target ?? selection
    }

    /// The inverse of `row(at:)` — where a screen puts the highlight after its own list moves.
    func index(section: Int, offset: Int) -> Int? {
        guard sectionCounts.indices.contains(section), offset >= 0,
            offset < sectionCounts[section]
        else { return nil }
        let preceding = sectionCounts[..<section].reduce(0, +)
        return (hasCalculator ? 1 : 0) + preceding + offset
    }
}
