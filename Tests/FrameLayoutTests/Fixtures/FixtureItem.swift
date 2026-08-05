import Foundation

struct FixtureItem: Hashable, Sendable, Identifiable {
    static var sample: FixtureItem {
        FixtureItem(
            id: "i1",
            initials: "AP",
            title: "Every level here is its own FLView",
            detail: "and the data is nested to match",
            badges: ["one", "two"],
            isFlagged: false
        )
    }

    let id: String
    let initials: String
    let title: String
    let detail: String?
    let badges: [String]
    let isFlagged: Bool

    func with(badges: [String]) -> FixtureItem {
        FixtureItem(id: id, initials: initials, title: title, detail: detail, badges: badges, isFlagged: isFlagged)
    }

    func with(detail: String?) -> FixtureItem {
        FixtureItem(id: id, initials: initials, title: title, detail: detail, badges: badges, isFlagged: isFlagged)
    }

    func with(isFlagged: Bool) -> FixtureItem {
        FixtureItem(id: id, initials: initials, title: title, detail: detail, badges: badges, isFlagged: isFlagged)
    }
}

enum FixturePart: Hashable, Sendable {
    case avatar(String)
    case title(String)
    case detail(String)
    case badges(String)
    case flag(String)
}
