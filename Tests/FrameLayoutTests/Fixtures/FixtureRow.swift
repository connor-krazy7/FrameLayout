import FrameLayout
import UIKit

struct FixtureRow: FLView {
    let item: FixtureItem

    var body: some FLNode {
        FLHStack(alignment: .top, spacing: 8) {
            FixtureAvatar(initials: item.initials, id: item.id)

            FixtureBody(item: item)
        }
        .padding(10)
        .background(.secondarySystemBackground, in: .roundedRectangle(12))
    }
}

struct FixtureAvatar: FLView {
    let initials: String
    let id: String

    var body: some FLNode {
        FLText(initials)
            .font(.systemFont(ofSize: 11, weight: .semibold))
            .padding(8)
            .background(.systemBlue, in: .roundedRectangle(14))
            .tag(FixturePart.avatar(id))
    }
}

struct FixtureBody: FLView {
    let item: FixtureItem

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 4) {
            FLText(item.title)
                .font(.systemFont(ofSize: 14, weight: .semibold))
                .tag(FixturePart.title(item.id))

            if let detail = item.detail {
                FLText(detail)
                    .font(.systemFont(ofSize: 12))
                    .tag(FixturePart.detail(item.id))
            }

            FixtureBadges(badges: item.badges, id: item.id)

            if item.isFlagged {
                FLButton(tag: FixturePart.flag(item.id)) {
                    FLText("flag")
                        .font(.systemFont(ofSize: 11))
                        .padding(6)
                        .background(.systemRed, in: .roundedRectangle(8))
                }
            }
        }
    }
}

struct FixtureBadges: FLView {
    let badges: [String]
    let id: String

    var body: some FLNode {
        FLHStack(spacing: 4) {
            FLForEach(badges, id: \.self) { badge in
                FLText(badge)
                    .font(.systemFont(ofSize: 10))
                    .padding(4)
                    .background(.tertiarySystemFill, in: .roundedRectangle(6))
            }
        }
        .tag(FixturePart.badges(id))
    }
}
