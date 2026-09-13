import UIKit

// MARK: - FLAttributedString

/// Attributed text with a layout identity that ignores the attributes which change no glyph advance.
/// A colour baked into a run is then free, the way `foregroundColor(_:)` already is.
///
/// `==` still compares the whole string, colours included, so a highlight change is still a change to
/// whoever is diffing a collection.
public struct FLAttributedString: Sendable, Hashable, FLLayoutEquatable {
    /// Applied at draw time and never read while measuring. Omitting a key from this list costs a
    /// missed merge; adding a metric-affecting one such as `.kern` or `.font` would be a wrong hit.
    private static let neutralAttributes: [NSAttributedString.Key] = [
        .foregroundColor,
        .backgroundColor,
        .underlineColor,
        .strikethroughColor,
    ]

    public nonisolated(unsafe) let underlying: NSAttributedString

    /// `underlying` itself when there was nothing to strip, so the common case allocates nothing.
    private nonisolated(unsafe) let layoutIdentity: NSAttributedString

    public init(_ underlying: NSAttributedString) {
        let snapshot = NSAttributedString(attributedString: underlying)

        self.underlying = snapshot
        layoutIdentity = Self.strippingNeutralAttributes(from: snapshot)
    }

    public init(_ underlying: AttributedString) {
        self.init(NSAttributedString(underlying))
    }

    public init(_ string: String) {
        self.init(NSAttributedString(string: string))
    }

    /// The string with `attributes` filled into the runs that do not already carry them. Defaults lose
    /// to whatever the string was built with, which is what lets a caller style part of a run and leave
    /// the rest to the environment.
    func text(withDefaults attributes: [NSAttributedString.Key: Any]) -> NSAttributedString {
        guard underlying.length > 0 else { return underlying }

        let filled = NSMutableAttributedString(attributedString: underlying)

        for (key, value) in attributes {
            Self.fillGaps(of: key, with: value, in: filled)
        }

        return filled
    }
}

// MARK: - Hashable

public extension FLAttributedString {
    static func == (lhs: FLAttributedString, rhs: FLAttributedString) -> Bool {
        lhs.underlying == rhs.underlying
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(underlying)
    }
}

// MARK: - FLLayoutEquatable

public extension FLAttributedString {
    func isLayoutEquivalent(to other: FLAttributedString) -> Bool {
        layoutIdentity == other.layoutIdentity
    }

    func hashLayoutIdentity(into hasher: inout Hasher) {
        hasher.combine(layoutIdentity)
    }
}

// MARK: - Helpers

private extension FLAttributedString {
    static func fillGaps(
        of key: NSAttributedString.Key,
        with value: Any,
        in target: NSMutableAttributedString
    ) {
        let fullRange = NSRange(location: 0, length: target.length)

        var missing: [NSRange] = []
        target.enumerateAttribute(key, in: fullRange, options: []) { existing, subrange, _ in
            guard existing == nil else { return }
            missing.append(subrange)
        }

        for subrange in missing {
            target.addAttribute(key, value: value, range: subrange)
        }
    }

    static func strippingNeutralAttributes(from string: NSAttributedString) -> NSAttributedString {
        let fullRange = NSRange(location: 0, length: string.length)

        guard carriesANeutralAttribute(string, in: fullRange) else { return string }

        let stripped = NSMutableAttributedString(attributedString: string)

        for key in neutralAttributes {
            stripped.removeAttribute(key, range: fullRange)
        }

        return stripped
    }

    static func carriesANeutralAttribute(_ string: NSAttributedString, in range: NSRange) -> Bool {
        var found = false

        string.enumerateAttributes(in: range, options: []) { attributes, _, stop in
            guard attributes.keys.contains(where: neutralAttributes.contains) else { return }

            found = true
            stop.pointee = true
        }

        return found
    }
}
