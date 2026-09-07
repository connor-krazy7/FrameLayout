import UIKit

/// The one TextKit 1 stack every text node measures through; see `concurrency.md`.
struct FLTextMeasurement {
    /// Must already carry the font it is measured against: `size(in:)` fills no attributes in, so a
    /// string with no `.font` is measured against TextKit's own default instead. `FLText` resolves
    /// against the environment first and passes `measuredText(in:)`.
    let attributedText: NSAttributedString
    let lineLimit: Int
    let lineBreakMode: NSLineBreakMode

    func size(in context: FLContext) -> CGSize {
        guard attributedText.length > 0 else { return .zero }

        let availableWidth = containerWidth(for: context.width)

        guard availableWidth > 0 else { return .zero }

        let storage = NSTextStorage(attributedString: attributedText)
        let container = NSTextContainer(
            size: CGSize(
                width: availableWidth,
                height: context.height.exactValue.or(.greatestFiniteMagnitude)
            )
        ).then {
            $0.lineFragmentPadding = 0
            $0.maximumNumberOfLines = lineLimit
            $0.lineBreakMode = lineBreakMode
        }
        let manager = NSLayoutManager()

        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)

        let used = manager.usedRect(for: container)

        return CGSize(
            width: context.clampingWidth(ceil(used.width)),
            height: context.clampingHeight(ceil(used.height))
        )
    }
}

// MARK: - Helpers

private extension FLTextMeasurement {
    func containerWidth(for proposal: FLProposal) -> CGFloat {
        switch proposal {
        case .unspecified, .maximum: .greatestFiniteMagnitude
        case .minimum: Self.minimumWidth(of: attributedText)
        case let .exact(value): value
        }
    }

    // TextKit cannot be asked for an intrinsic minimum: a zero-width container is treated as
    // unbounded, and any small width simply wraps inside words. So the minimum is a policy — the
    // widest run that cannot be broken — and here that policy is "break only at whitespace".
    //
    // Hyphens and other break opportunities are not considered, so this can over-report. That is the
    // safe direction: an over-large minimum makes a container refuse to squeeze text further than it
    // should, where an under-report would let it wrap into something unreadable.
    static func minimumWidth(of attributedText: NSAttributedString) -> CGFloat {
        let string = attributedText.string as NSString
        let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        var widest: CGFloat = 0
        var searchStart = 0

        while searchStart < string.length {
            let remaining = NSRange(location: searchStart, length: string.length - searchStart)
            let separator = string.rangeOfCharacter(from: .whitespacesAndNewlines, options: [], range: remaining)

            let runRange: NSRange
            if separator.location == NSNotFound {
                runRange = remaining
                searchStart = string.length
            } else {
                runRange = NSRange(location: searchStart, length: separator.location - searchStart)
                searchStart = separator.location + separator.length
            }

            guard runRange.length > 0 else { continue }

            let bounds = attributedText
                .attributedSubstring(from: runRange)
                .boundingRect(with: unbounded, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            widest = Swift.max(widest, ceil(bounds.width))
        }

        return widest
    }
}
