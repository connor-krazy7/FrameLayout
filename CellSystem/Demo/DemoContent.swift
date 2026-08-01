import UIKit

enum DemoPalette {
    static var bubble: UIColor { UIColor(hex: 0x1C1C1E) }
    static var accent: UIColor { UIColor(hex: 0x0075FB) }
    static var text: UIColor { UIColor(white: 1) }
    static var secondaryText: UIColor { UIColor(white: 0.6) }
    static var divider: UIColor { UIColor(white: 0.12) }
}

enum DemoFont {
    static var body: UIFont { .systemFont(ofSize: 16) }
    static var caption: UIFont { .systemFont(ofSize: 14) }
    static var chip: UIFont { .systemFont(ofSize: 14, weight: .medium) }
    static var title: UIFont { .systemFont(ofSize: 17, weight: .semibold) }
}

struct DemoBubble: FLView {
    let text: String

    var body: some FLNode {
        FLText(text)
            .padding(.horizontal, 16)
            .padding(top: 12, bottom: 12)
            .background(DemoPalette.bubble, in: .roundedRectangle(20), curve: .continuous)
            .font(DemoFont.body)
            .foregroundColor(DemoPalette.text)
    }
}

struct DemoChip: FLView {
    let title: String

    var body: some FLNode {
        FLText(title)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(DemoPalette.accent, in: .roundedRectangle(16))
            .font(DemoFont.chip)
            .foregroundColor(DemoPalette.text)
    }
}

struct DemoAvatar: FLView {
    var diameter: CGFloat = 44

    var body: some FLNode {
        FLImage(UIImage(systemName: "person.fill"))
            .padding(10)
            .frame(width: diameter, height: diameter)
            .background(DemoPalette.accent)
            .clipShape(.capsule, curve: .continuous)
            .foregroundColor(DemoPalette.text)
    }
}

struct DemoDivider: FLView {
    var body: some FLNode {
        FLColor(DemoPalette.divider).frame(height: 1)
    }
}

struct DemoRow: FLView {
    let title: String
    let value: String

    var body: some FLNode {
        FLHStack(spacing: 8) {
            FLText(title).foregroundColor(DemoPalette.secondaryText)
            FLSpacer()
            FLText(value)
        }
        .font(DemoFont.caption)
        .foregroundColor(DemoPalette.text)
    }
}

struct DemoCard: FLView {
    let sender: String
    let amount: String
    let action: String

    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 12) {
            FLText("Transfer").font(DemoFont.title)
            DemoRow(title: "From", value: sender)
            DemoRow(title: "Amount", value: amount)
            DemoChip(title: action)
        }
        .padding(16)
        .background(DemoPalette.bubble, in: .roundedRectangle(20), curve: .continuous)
        .font(DemoFont.body)
        .foregroundColor(DemoPalette.text)
    }
}
