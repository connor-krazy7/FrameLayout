import UIKit

public struct FLLayeredLayout<PrimaryLayout: FLLayout, SecondaryLayout: FLLayout>: FLLayout {
    public let primary: PrimaryLayout
    public let secondary: SecondaryLayout
    public let secondaryFrame: CGRect

    public var size: CGSize { primary.size }
}

public enum FLLayered {
    public static func layout<Primary: FLNode, Secondary: FLNode>(
        primary: Primary,
        secondary: Secondary,
        alignment: FLAlignment,
        in context: FLContext
    ) -> FLLayeredLayout<Primary.Layout, Secondary.Layout> {
        let primaryLayout = primary.layout(in: context)
        let secondaryLayout = secondary.layout(
            in: context.proposing(
                width: .exact(primaryLayout.size.width),
                height: .exact(primaryLayout.size.height)
            )
        )

        return FLLayeredLayout(
            primary: primaryLayout,
            secondary: secondaryLayout,
            secondaryFrame: CGRect(
                origin: alignment.origin(
                    childSize: secondaryLayout.size,
                    containerSize: primaryLayout.size,
                    direction: context.layoutDirection
                ),
                size: secondaryLayout.size
            )
        )
    }
}
