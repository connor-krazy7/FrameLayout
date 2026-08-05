import UIKit

@MainActor
public final class FLViewRegistry {
    private var tagToView: [AnyHashable: UIView] = [:]
    private var tagToBindings: [AnyHashable: [AnyHashable: Binding]] = [:]

    public var count: Int { tagToView.count }
    public var tags: Set<AnyHashable> { Set(tagToView.keys) }

    public func view<Tag: Hashable>(withTag tag: Tag) -> UIView? {
        tagToView[AnyHashable(tag)]
    }

    public func button<Tag: Hashable>(withTag tag: Tag) -> UIControl? {
        view(withTag: tag) as? UIControl
    }

    public func view<Tag: Hashable, Kind: UIView>(withTag tag: Tag, as kind: Kind.Type) -> Kind? {
        guard let tagged = view(withTag: tag) else { return nil }

        return tagged as? Kind ?? Self.firstDescendant(of: kind, in: tagged)
    }

    public func imageView<Tag: Hashable>(withTag tag: Tag) -> UIImageView? {
        view(withTag: tag, as: UIImageView.self)
    }

    public func label<Tag: Hashable>(withTag tag: Tag) -> UILabel? {
        view(withTag: tag, as: UILabel.self)
    }

    public func containsView<Tag: Hashable>(withTag tag: Tag) -> Bool {
        tagToView[AnyHashable(tag)] != nil
    }

    public func bindView<Tag: Hashable>(
        withTag tag: Tag,
        _ configure: @escaping @MainActor (UIView) -> Void
    ) {
        bind(tag: AnyHashable(tag), bindingKey: Constants.BindingKey.defaultKey, configure: configure)
    }

    public func bindView<Tag: Hashable, Key: Hashable>(
        withTag tag: Tag,
        bindingKey: Key,
        _ configure: @escaping @MainActor (UIView) -> Void
    ) {
        bind(tag: AnyHashable(tag), bindingKey: AnyHashable(bindingKey), configure: configure)
    }

    public func bindButton<Tag: Hashable>(
        withTag tag: Tag,
        _ configure: @escaping @MainActor (UIControl) -> Void
    ) {
        bindView(withTag: tag) { view in
            guard let control = view as? UIControl else { return }

            configure(control)
        }
    }

    public func bindButton<Tag: Hashable, Key: Hashable>(
        withTag tag: Tag,
        bindingKey: Key,
        _ configure: @escaping @MainActor (UIControl) -> Void
    ) {
        bindView(withTag: tag, bindingKey: bindingKey) { view in
            guard let control = view as? UIControl else { return }

            configure(control)
        }
    }

    public func bindAction<Tag: Hashable>(
        withTag tag: Tag,
        for events: UIControl.Event = .touchUpInside,
        _ handler: @escaping @MainActor (UIControl.Event) -> Void
    ) {
        bindAction(
            tag: AnyHashable(tag),
            bindingKey: Constants.BindingKey.defaultActionKey,
            events: events,
            handler: handler
        )
    }

    public func bindAction<Tag: Hashable, Key: Hashable>(
        withTag tag: Tag,
        for events: UIControl.Event = .touchUpInside,
        bindingKey: Key,
        _ handler: @escaping @MainActor (UIControl.Event) -> Void
    ) {
        bindAction(
            tag: AnyHashable(tag),
            bindingKey: AnyHashable(bindingKey),
            events: events,
            handler: handler
        )
    }

    public func unbindView<Tag: Hashable>(withTag tag: Tag) {
        unbind(tag: AnyHashable(tag), bindingKey: Constants.BindingKey.defaultKey)
    }

    public func unbindView<Tag: Hashable, Key: Hashable>(withTag tag: Tag, bindingKey: Key) {
        unbind(tag: AnyHashable(tag), bindingKey: AnyHashable(bindingKey))
    }

    public func unbindButton<Tag: Hashable>(withTag tag: Tag) {
        unbindView(withTag: tag)
    }

    public func unbindButton<Tag: Hashable, Key: Hashable>(withTag tag: Tag, bindingKey: Key) {
        unbindView(withTag: tag, bindingKey: bindingKey)
    }

    public func unbindAction<Tag: Hashable>(withTag tag: Tag) {
        unbindAction(tag: AnyHashable(tag), bindingKey: Constants.BindingKey.defaultActionKey)
    }

    public func unbindAction<Tag: Hashable, Key: Hashable>(withTag tag: Tag, bindingKey: Key) {
        unbindAction(tag: AnyHashable(tag), bindingKey: AnyHashable(bindingKey))
    }

    public func unbindAll<Tag: Hashable>(withTag tag: Tag) {
        unbindAll(tag: AnyHashable(tag))
    }

    public func unbindAll() {
        for tag in Array(tagToBindings.keys) {
            unbindAll(tag: tag)
        }
    }

    public func registerView<Tag: Hashable>(_ view: UIView, withTag tag: Tag) {
        let tag = AnyHashable(tag)

        tagToView[tag] = view
        applyBindings(tag: tag)
    }

    public func removeAll() {
        tagToView.removeAll(keepingCapacity: true)
    }
}

// MARK: - Private methods

private extension FLViewRegistry {
    func bind(
        tag: AnyHashable,
        bindingKey: AnyHashable,
        configure: @escaping @MainActor (UIView) -> Void
    ) {
        tagToBindings[tag] = tagToBindings[tag, default: [:]].with { $0[bindingKey] = Binding(configure) }
        applyBindings(tag: tag)
    }

    func bindAction(
        tag: AnyHashable,
        bindingKey: AnyHashable,
        events: UIControl.Event,
        handler: @escaping @MainActor (UIControl.Event) -> Void
    ) {
        let actionIdentifier = Constants.ActionIdentifier.identifier(tag: tag, bindingKey: bindingKey)

        bind(tag: tag, bindingKey: bindingKey) { view in
            guard let control = view as? UIControl else { return }

            Self.removeActions(identifiedBy: actionIdentifier, fromControl: control)
            Self.addActions(identifiedBy: actionIdentifier, for: events, toControl: control, handler)
        }
    }

    func unbindAll(tag: AnyHashable) {
        guard let bindings = tagToBindings[tag] else { return }

        for bindingKey in bindings.keys {
            unbindAction(tag: tag, bindingKey: bindingKey)
        }
    }

    func unbind(tag: AnyHashable, bindingKey: AnyHashable) {
        tagToBindings[tag] = tagToBindings[tag]
            .map { $0.with { $0[bindingKey] = nil } }
            .flatMap { $0.isEmpty ? nil : $0 }
    }

    func unbindAction(tag: AnyHashable, bindingKey: AnyHashable) {
        let actionIdentifier = Constants.ActionIdentifier.identifier(tag: tag, bindingKey: bindingKey)

        unbind(tag: tag, bindingKey: bindingKey)

        guard let button = tagToView[tag] as? UIControl else { return }

        Self.removeActions(identifiedBy: actionIdentifier, fromControl: button)
    }

    static func firstDescendant<Kind: UIView>(of kind: Kind.Type, in view: UIView) -> Kind? {
        for subview in view.subviews {
            if let match = subview as? Kind ?? firstDescendant(of: kind, in: subview) {
                return match
            }
        }

        return nil
    }

    func applyBindings(tag: AnyHashable) {
        guard let view = tagToView[tag], let bindings = tagToBindings[tag] else { return }

        for binding in bindings.values where binding.boundView !== view {
            binding.boundView = view
            binding.configure(view)
        }
    }

    static func removeActions(
        identifiedBy identifier: UIAction.Identifier,
        fromControl control: UIControl
    ) {
        for event in Constants.UIControlEvents.addressable {
            let actionIdentifier = Constants.ActionIdentifier.identifier(base: identifier, event: event)

            control.removeAction(identifiedBy: actionIdentifier, for: event)
        }
    }

    static func addActions(
        identifiedBy identifier: UIAction.Identifier,
        for events: UIControl.Event,
        toControl control: UIControl,
        _ handler: @escaping @MainActor (UIControl.Event) -> Void
    ) {
        let matchedEvents = Constants.UIControlEvents.addressable.filter { events.contains($0) }

        for event in matchedEvents {
            let actionIdentifier = Constants.ActionIdentifier.identifier(base: identifier, event: event)

            control.addAction(UIAction(identifier: actionIdentifier) { _ in handler(event) }, for: event)
        }
    }
}

// MARK: - Nested types

private extension FLViewRegistry {
    final class Binding {
        let configure: @MainActor (UIView) -> Void

        weak var boundView: UIView?

        init(_ configure: @escaping @MainActor (UIView) -> Void) {
            self.configure = configure
        }
    }

    enum Constants {
        enum BindingKey {
            static nonisolated(unsafe) let defaultKey = AnyHashable("FLViewRegistry.binding")

            static nonisolated(unsafe) let defaultActionKey = AnyHashable("FLViewRegistry.action")
        }

        enum ActionIdentifier {
            static func identifier(tag: AnyHashable, bindingKey: AnyHashable) -> UIAction.Identifier {
                UIAction.Identifier("FLBinding.\(tag.base).\(bindingKey.base)")
            }

            static func identifier(base: UIAction.Identifier, event: UIControl.Event) -> UIAction.Identifier {
                UIAction.Identifier("\(base.rawValue).\(event.rawValue)")
            }
        }

        enum UIControlEvents {
            static let addressable: [UIControl.Event] = [
                .touchDown,
                .touchDownRepeat,
                .touchDragInside,
                .touchDragOutside,
                .touchDragEnter,
                .touchDragExit,
                .touchUpInside,
                .touchUpOutside,
                .touchCancel,
                .valueChanged,
                .menuActionTriggered,
                .primaryActionTriggered,
                .editingDidBegin,
                .editingChanged,
                .editingDidEnd,
                .editingDidEndOnExit,
            ]
        }
    }
}
