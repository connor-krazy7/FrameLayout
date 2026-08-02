import Testing
import UIKit

@testable import CellSystem

private enum Part: Hashable, Sendable {
    case avatar
    case title
    case bubble
    case spacerOnly
}

private struct Row: FLView {
    var body: some FLNode {
        FLVStack(alignment: .leading, spacing: 8) {
            FLImage(UIImage(systemName: "person.crop.circle"))
                .frame(width: 40, height: 40)
                .tag(Part.avatar)

            FLText("Ann Petrova")
                .font(.systemFont(ofSize: 15))
                .tag(Part.title)

            FLButton(tag: Part.bubble) {
                FLText("Hello there")
                    .padding(10)
                    .background(.systemBlue, in: .roundedRectangle(12))
            }

            FLSpacer()
                .frame(width: 40, height: 10)
                .tag(Part.spacerOnly)
        }
    }
}

@MainActor
@Suite("Typed lookup")
struct FLTypedLookupTests {
    private let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 480))

    private func hosted() -> FLHost<Row> {
        let host = FLHost<Row>()
        let node = Row().node
        let layout = node.layout(in: FLContext(width: 300))

        window.addSubview(host)
        window.makeKeyAndVisible()
        host.frame = CGRect(origin: .zero, size: layout.size)
        host.apply(node: node, layout: layout)
        host.layoutIfNeeded()

        return host
    }

    @Test("the UIImageView inside FLImage is reachable, even though the tag names the region")
    func imageViewIsReachable() {
        let host = hosted()
        let imageView = host.registry.imageView(withTag: Part.avatar)

        #expect(imageView != nil)
        #expect(imageView?.image != nil)
        #expect(host.registry.view(withTag: Part.avatar) is FLImageView == false)
    }

    @Test("a library can drive the image view it was handed")
    func imageViewIsUsable() {
        let host = hosted()
        let imageView = host.registry.imageView(withTag: Part.avatar)
        let replacement = UIImage(systemName: "star.fill")

        imageView?.image = replacement

        #expect(host.registry.imageView(withTag: Part.avatar)?.image === replacement)
    }

    @Test("FLText's view is a UILabel, so it matches at the top rather than by searching")
    func labelMatchesDirectly() {
        let host = hosted()

        #expect(host.registry.label(withTag: Part.title)?.text == "Ann Petrova")
        #expect(host.registry.view(withTag: Part.title, as: UILabel.self) is FLTextView)
    }

    @Test("the search reaches through a button into its content")
    func searchReachesThroughAButton() {
        let host = hosted()

        #expect(host.registry.button(withTag: Part.bubble) != nil)
        #expect(host.registry.label(withTag: Part.bubble)?.text == "Hello there")
    }

    @Test("a region with nothing of that kind resolves to nothing")
    func noMatchResolvesToNil() {
        let host = hosted()

        #expect(host.registry.imageView(withTag: Part.spacerOnly) == nil)
        #expect(host.registry.label(withTag: Part.avatar) == nil)
        #expect(host.registry.imageView(withTag: Part.title) == nil)
    }

    @Test("an unknown tag resolves to nothing rather than searching the whole tree")
    func unknownTagResolvesToNil() {
        let host = hosted()

        #expect(host.registry.imageView(withTag: "nothing") == nil)
        #expect(host.registry.view(withTag: "nothing", as: UIView.self) == nil)
    }
}
