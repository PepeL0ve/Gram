import Foundation
import SwiftSignalKit
import Postbox

/// KW Gram "Персональные цвета" — the runtime half.
///
/// Telegram colours a user's own name (in every chat they write to, and in their profile
/// header) and their profile background through `engine.accountData.updateNameColorAndEmoji`.
/// KW Gram lets the user pick any colour from the palette and keeps applying it, so that even
/// after Telegram resets it (or the user changes it in the real settings), KW Gram restores the
/// chosen colour.
///
/// The engine call itself is injected from `AccountContext` (see the patch) as
/// `applyColor(nameColorIndex:profileColorIndex:)` — this module depends on neither
/// TelegramCore nor AccountContext, so the engine is reached only through the closure, exactly
/// like `KWGramTimeInNicknameRuntime` reaches the account name.
///
/// - `observe` subscribes to the stored colours and, on any change, invokes the injected apply.
/// - `applyNow` is the one-shot path (used right after the user picks a colour in the UI).
public final class KWGramPersonalColorRuntime {
    /// Applies the given raw colour indices to the real account. `nil` means "leave that one
    /// unchanged"; both `nil` means "no colour chosen", so nothing is sent.
    public typealias Apply = (Int32?, Int32?) -> Void

    private let apply: Apply
    private var disposable: Disposable?

    public init(apply: @escaping Apply) {
        self.apply = apply
    }

    deinit {
        self.disposable?.dispose()
    }

    /// Subscribe to the stored colours and apply them on every change. Also applies once on
    /// subscription so the account matches the stored choice at launch. The caller owns the
    /// returned disposable.
    @discardableResult
    public func observe(postbox: Postbox) -> Disposable {
        self.disposable?.dispose()
        let d = (KWGramPersonalColorStore.signal(postbox: postbox)
        |> deliverOnMainQueue).start(next: { [weak self] colors in
            self?.applyColor(colors)
        })
        self.disposable = d
        return d
    }

    /// Apply the currently stored colours once, immediately.
    public func applyNow(postbox: Postbox) {
        self.applyColor(KWGramPersonalColorStore.read(postbox: postbox))
    }

    private func applyColor(_ colors: KWGramPersonalColors) {
        guard colors.nameColorIndex != nil || colors.profileColorIndex != nil else {
            return
        }
        self.apply(colors.nameColorIndex, colors.profileColorIndex)
    }
}
