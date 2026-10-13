import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import Display
import KWGramCore

/// KW Gram "Поиск подарков" — the seam between the «Подарки» search tab and TelegramUI.
///
/// The tab itself lives in ChatListUI (`ChatListSearchListPaneNode`), which may not depend
/// on TelegramUI — and the gift details screen (`GiftViewScreen`) lives there. So the push
/// closure is installed once from `AccountContextImpl` at launch (see the patch), and the
/// tab's visibility flag mirrors the stored `KWGramSettings.giftSearchTab` switch
/// («Чаты» → «Поиск подарков») through `KWGramGiftSearchRuntime`.
public enum KWGramGiftSearchBridge {
    private static let lock = NSLock()
    private static var presentGiftValue: ((AccountContext, StarGift, NavigationController?) -> Void)?
    private static let tabEnabledValue = Atomic<Bool>(value: true)

    /// Called once from `AccountContextImpl.init` (main app only). The closure is
    /// account-agnostic: it only uses the arguments the tab passes in.
    public static func install(presentGift: @escaping (AccountContext, StarGift, NavigationController?) -> Void) {
        self.lock.lock()
        self.presentGiftValue = presentGift
        self.lock.unlock()
    }

    /// Pushes the gift details screen for the given catalog/collection gift. Called by the
    /// «Подарки» tab when the user taps a gift row.
    public static func presentGift(context: AccountContext, gift: StarGift, navigationController: NavigationController?) {
        self.lock.lock()
        let presentGift = self.presentGiftValue
        self.lock.unlock()
        presentGift?(context, gift, navigationController)
    }

    /// Whether the «Подарки» chip is shown in the global search. Starts at `true` — the
    /// stored default of `KWGramSettings.giftSearchTab` — and is kept in sync on every
    /// settings change by `KWGramGiftSearchRuntime` (written on the main queue, read by the
    /// search UI on the main thread).
    public static var tabEnabled: Bool {
        get {
            return self.tabEnabledValue.with { $0 }
        }
        set {
            _ = self.tabEnabledValue.swap(newValue)
        }
    }
}

/// Runtime half: mirrors this account's stored «Поиск подарков» switch into
/// `KWGramGiftSearchBridge.tabEnabled`. Started from `AccountContextImpl` at launch (see
/// the patch), exactly like `KWGramMonoColorRuntime` / `KWGramFakeAdminRuntime`.
///
/// Reads the RAW settings (not the gifts-gated view): the tab is a «Чаты» feature, so the
/// «Включить визуалку» master switch must not hide it.
public final class KWGramGiftSearchRuntime {
    public static let shared = KWGramGiftSearchRuntime()

    private let lock = NSLock()
    private var startedAccounts: Set<Int64> = []
    private var disposables: [Int64: Disposable] = [:]

    private init() {
    }

    /// Mirror this account's stored switch into `tabEnabled` and keep it updated on every
    /// change. Idempotent per account.
    public func start(accountKey: Int64, postbox: Postbox) {
        self.lock.lock()
        if self.startedAccounts.contains(accountKey) {
            self.lock.unlock()
            return
        }
        self.startedAccounts.insert(accountKey)
        self.lock.unlock()

        let disposable = (KWGramCore.rawSettingsSignal(postbox: postbox)
        |> map { settings -> Bool in
            return settings.giftSearchTab
        }
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { enabled in
            KWGramGiftSearchBridge.tabEnabled = enabled
        })

        self.lock.lock()
        self.disposables[accountKey] = disposable
        self.lock.unlock()
    }
}
