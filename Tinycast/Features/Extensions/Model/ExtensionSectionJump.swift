/// ⌘↓ / ⌘↑ over a List or Grid's sections: the next one's first row, or this one's going back.
struct ExtensionSectionJump {
    /// Selectable rows per section in visible order; a section with none is not a stop.
    let counts: [Int]

    func target(_ delta: Int, from index: Int) -> Int {
        let total = counts.reduce(0, +)
        guard total > 0 else { return 0 }
        let selection = min(max(index, 0), total - 1)
        var starts: [Int] = []
        var next = 0
        for count in counts where count > 0 {
            starts.append(next)
            next += count
        }
        let stop = delta > 0 ? starts.first { $0 > selection } : starts.last { $0 < selection }
        return stop ?? selection
    }
}
