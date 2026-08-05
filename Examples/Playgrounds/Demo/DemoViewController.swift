import FrameLayout
import UIKit

@MainActor
final class DemoViewController: UIViewController {
    private enum DemoText {
        static var short: String { "Composites: the UIKit side names one type." }
        static var long: String {
            """
            Composites: the UIKit side names one type.

            A composite hides its composed tree behind an opaque body, so hosting it needs only \
            FLHost<DemoBubble> rather than the whole generic chain. Tap to mutate the content and \
            watch the host animate to the newly computed size.
            """
        }
    }

    private enum Layout {
        static var horizontalInset: CGFloat { 16 }
        static var verticalSpacing: CGFloat { 16 }
    }

    private let scrollView = UIScrollView()
    private let bubbleHost = FLHost<DemoBubble>()
    private let avatarHost = FLHost<DemoAvatar>()
    private let dividerHost = FLHost<DemoDivider>()
    private let cardHost = FLHost<DemoCard>()
    private let chipHost = FLHost<DemoChip>()

    private let bubbleLayoutCache = FLLayoutCache<FLComposed<DemoBubble>>()

    private var isExpanded = false
    private var lastLayoutWidth: CGFloat = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)

        for host in orderedHosts {
            scrollView.addSubview(host)
        }

        bubbleHost.isUserInteractionEnabled = true
        bubbleHost.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(didTapBubble))
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let availableWidth = view.bounds.width - Layout.horizontalInset * 2
        guard availableWidth > 0, availableWidth != lastLayoutWidth else { return }

        lastLayoutWidth = availableWidth
        reload(animated: false)
    }

    @objc
    private func didTapBubble() {
        isExpanded.toggle()
        reload(animated: true)
    }

    private func reload(animated: Bool) {
        let context = FLContext(
            width: lastLayoutWidth,
            layoutDirection: view.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight,
            contentSizeCategory: traitCollection.preferredContentSizeCategory.rawValue
        )

        // Each `.node` builds its body once; reusing the value avoids rebuilding it per pass.
        let bubble = DemoBubble(text: isExpanded ? DemoText.long : DemoText.short).node
        let avatar = DemoAvatar().node
        let divider = DemoDivider().node
        let card = DemoCard(
            sender: "alien.eth",
            amount: isExpanded ? "1,204.55 ALN" : "12 ALN",
            action: "Confirm"
        ).node
        let chip = DemoChip(title: "Reply").node

        Task {
            let bubbleLayout = await FLLayoutComputer.layout(bubble, in: context)
            let avatarLayout = await FLLayoutComputer.layout(avatar, in: context)
            let dividerLayout = await FLLayoutComputer.layout(divider, in: context)
            let cardLayout = await FLLayoutComputer.layout(card, in: context)
            let chipLayout = await FLLayoutComputer.layout(chip, in: context)

            logDiagnostics(bubble: bubble, layout: bubbleLayout, in: context)

            let apply = {
                self.bubbleHost.apply(node: bubble, layout: bubbleLayout)
                self.avatarHost.apply(node: avatar, layout: avatarLayout)
                self.dividerHost.apply(node: divider, layout: dividerLayout)
                self.cardHost.apply(node: card, layout: cardLayout)
                self.chipHost.apply(node: chip, layout: chipLayout)
                self.positionHosts()
            }

            if animated {
                UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseInOut], animations: apply)
            } else {
                apply()
            }
        }
    }

    private var orderedHosts: [any FLHosting] {
        [bubbleHost, avatarHost, dividerHost, cardHost, chipHost]
    }

    private func positionHosts() {
        var offsetY = view.safeAreaInsets.top + Layout.verticalSpacing

        for host in orderedHosts {
            host.frame = CGRect(
                origin: CGPoint(x: Layout.horizontalInset, y: offsetY),
                size: host.contentSize
            )
            offsetY += host.contentSize.height + Layout.verticalSpacing
        }

        scrollView.contentSize = CGSize(width: view.bounds.width, height: offsetY)
    }

    private func logDiagnostics(
        bubble: FLComposed<DemoBubble>,
        layout: FLComposed<DemoBubble>.Layout,
        in context: FLContext
    ) {
        _ = bubbleLayoutCache.layout(for: bubble, in: context)
        _ = bubbleLayoutCache.layout(for: bubble, in: context)

        print("typeIdentifier: \(FLComposed<DemoBubble>.typeIdentifier)")
        print("size: \(layout.size)")
        print("cache entries after two lookups of the same content: \(bubbleLayoutCache.count)")
    }
}
