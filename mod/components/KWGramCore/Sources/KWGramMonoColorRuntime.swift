import Foundation
import SwiftSignalKit
import Postbox

/// KW Gram "MonoColor UI" — the runtime half.
///
/// The feature repaints the whole interface in one single tone: placeholder avatars, story
/// rings, name colours in chats and chat lists, chat-folder tags and profile colours all
/// resolve to the same colour while it is on (the colour itself and the switch live in
/// `KWGramAppearanceState`, edited from «Внешний вид» → «MonoColor UI»).
///
/// The render-time hooks (`PeerNameColors.get`, `AvatarNode.Colors(theme:)`,
/// `calculateAvatarColors`, …) are synchronous, but the stored preference can only be read
/// through the Postbox signal — so this singleton mirrors the preference into an `Atomic`
/// that the hooks consult. `start(accountKey:postbox:)` is called from `AccountContextImpl`
/// at launch (see the patch), exactly like `KWGramFakeAdminRuntime`.
///
/// Appearance preferences are per-account, while the hooks that read the colour have no
/// account at hand — so every account subscribes and the last value emitted wins. With a
/// single account (the normal case) that is precisely the stored choice.
public final class KWGramMonoColorRuntime {
    public static let shared = KWGramMonoColorRuntime()

    private let lock = NSLock()
    private var startedAccounts: Set<Int64> = []
    private var disposables: [Int64: Disposable] = [:]
    private let colorRGB = Atomic<UInt32?>(value: nil)

    private init() {
    }

    /// The active tone as `0xRRGGBB`, or `nil` when MonoColor UI is off — the one value
    /// every hook branches on.
    public static var activeColorRGB: UInt32? {
        return shared.colorRGB.with { $0 }
    }

    /// Mirror this account's stored MonoColor choice into `activeColorRGB` and keep it
    /// updated on every change. Idempotent per account.
    public func start(accountKey: Int64, postbox: Postbox) {
        self.lock.lock()
        if self.startedAccounts.contains(accountKey) {
            self.lock.unlock()
            return
        }
        self.startedAccounts.insert(accountKey)
        self.lock.unlock()

        let disposable = (KWGramAppearanceStore.signal(postbox: postbox)
        |> map { state -> UInt32? in
            guard state.monoColorEnabled else {
                return nil
            }
            return kwGramParseHexColor(state.monoColorHex)
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] rgb in
            _ = self?.colorRGB.swap(rgb)
        })

        self.lock.lock()
        self.disposables[accountKey] = disposable
        self.lock.unlock()
    }
}

/// Parses `#RRGGBB` / `RRGGBB` (also tolerating `#RGB`) into `0xRRGGBB`; `nil` when the
/// text is not a colour. Shared by the runtime and the settings UI validation.
public func kwGramParseHexColor(_ text: String) -> UInt32? {
    var hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if hex.hasPrefix("#") {
        hex = String(hex.dropFirst())
    }
    if hex.count == 3 {
        hex = hex.map { "\($0)\($0)" }.joined()
    }
    guard hex.count == 6 else {
        return nil
    }
    return UInt32(hex, radix: 16)
}

/// Formats `0xRRGGBB` back into the canonical `#RRGGBB` form stored in the preference.
public func kwGramFormatHexColor(_ rgb: UInt32) -> String {
    return String(format: "#%06X", rgb & 0xFFFFFF)
}
