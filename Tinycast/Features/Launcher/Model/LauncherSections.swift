/// The launcher's sections in draw order, so its headers and its ⌘↑/⌘↓ stops read one rule.
struct LauncherSections<Group: Equatable>: Equatable {
    enum Kind: Equatable {
        case card
        case favorites
        case meetings
        case suggestions
        case results
        case group(Group)
        case files
        case fallbacks
    }

    struct Section: Equatable {
        let kind: Kind
        let count: Int
    }

    /// Empty sections are absent, so every entry is a header with at least one row under it.
    let sections: [Section]

    /// `rest` is each remaining result's group in flat order; a run of equal groups is one section.
    init(
        hasCard: Bool, favorites: Int, meetings: Int, suggestions: Int, matches: Int, rest: [Group],
        files: Int, fallbacks: Int
    ) {
        var sections: [Section] = []
        func add(_ kind: Kind, _ count: Int) {
            if count > 0 { sections.append(Section(kind: kind, count: count)) }
        }
        add(.card, hasCard ? 1 : 0)
        add(.favorites, favorites)
        add(.meetings, meetings)
        add(.suggestions, suggestions)
        add(.results, matches)
        var current: Group?
        for group in rest {
            if group == current {
                sections[sections.count - 1] = Section(
                    kind: .group(group), count: sections[sections.count - 1].count + 1)
            } else {
                add(.group(group), 1)
                current = group
            }
        }
        add(.files, files)
        add(.fallbacks, fallbacks)
        self.sections = sections
    }

    var counts: [Int] { sections.map(\.count) }
}
