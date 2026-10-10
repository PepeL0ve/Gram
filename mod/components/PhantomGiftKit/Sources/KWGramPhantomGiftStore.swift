import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import KWGramCore

private struct KWGramPhantomGiftList: Codable {
    var gifts: [KWGramPhantomGift]
}

/// Persistent, entirely local storage for Phantom Gifts. Backed by Postbox's own
/// `PreferencesEntry` mechanism under the mod's reserved key range (see
/// `KWGramPreferencesKeys`), so it survives app restarts for free and needs no separate
/// file or database of its own. Nothing in this file ever touches `account.network` —
/// every operation is a local Postbox transaction.
///
/// The fake Stars balance lives in `KWGramSettings` rather than here, so the KW Gram
/// settings screen and the gift flow read and write exactly one value.
public enum KWGramPhantomGiftStore {
    public static var defaultFakeStarsBalance: Int64 {
        return KWGramSettings.defaultFakeStarsBalance
    }

    public static func allGifts(transaction: Transaction) -> [KWGramPhantomGift] {
        return transaction.getPreferencesEntry(key: KWGramPreferencesKeys.phantomGifts)?.get(KWGramPhantomGiftList.self)?.gifts ?? []
    }

    public static func gifts(transaction: Transaction, peerId: EnginePeer.Id) -> [KWGramPhantomGift] {
        return self.allGifts(transaction: transaction).filter { $0.peerId == peerId }
    }

    public static func add(transaction: Transaction, gift: KWGramPhantomGift) {
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.phantomGifts, { entry in
            var list = entry?.get(KWGramPhantomGiftList.self) ?? KWGramPhantomGiftList(gifts: [])
            list.gifts.append(gift)
            return PreferencesEntry(list)
        })
    }

    public static func remove(transaction: Transaction, id: Int64) {
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.phantomGifts, { entry in
            var list = entry?.get(KWGramPhantomGiftList.self) ?? KWGramPhantomGiftList(gifts: [])
            list.gifts.removeAll(where: { $0.id == id })
            return PreferencesEntry(list)
        })
    }

    /// Rewrites one gift in place (matched by `id`) — used for the profile-grid actions
    /// (pin/hide) that only flip a flag on an existing record rather than replacing it.
    /// A no-op if `id` isn't found.
    public static func update(transaction: Transaction, id: Int64, _ f: (KWGramPhantomGift) -> KWGramPhantomGift) {
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.phantomGifts, { entry in
            var list = entry?.get(KWGramPhantomGiftList.self) ?? KWGramPhantomGiftList(gifts: [])
            if let index = list.gifts.firstIndex(where: { $0.id == id }) {
                list.gifts[index] = f(list.gifts[index])
            }
            return PreferencesEntry(list)
        })
    }

    public static func fakeStarsBalance(transaction: Transaction) -> Int64 {
        return KWGramCore.settings(transaction: transaction).fakeStarsBalance
    }

    public static func setFakeStarsBalance(transaction: Transaction, stars: Int64) {
        KWGramCore.updateSettings(transaction: transaction, { settings in
            var settings = settings
            settings.fakeStarsBalance = stars
            return settings
        })
    }

    public static func fakeTonBalanceNanos(transaction: Transaction) -> Int64 {
        return KWGramCore.settings(transaction: transaction).fakeTonBalanceNanos
    }

    public static func setFakeTonBalanceNanos(transaction: Transaction, nanos: Int64) {
        KWGramCore.updateSettings(transaction: transaction, { settings in
            var settings = settings
            settings.fakeTonBalanceNanos = nanos
            return settings
        })
    }

    /// Live fake balance, for display (e.g. the "⭐ 50 000" label in the composer).
    public static func fakeStarsBalanceSignal(context: AccountContext) -> Signal<Int64, NoError> {
        return KWGramCore.settingsSignal(postbox: context.account.postbox)
        |> map { $0.fakeStarsBalance }
        |> distinctUntilChanged
    }

    /// Live list of every Phantom Gift on this device, newest first.
    public static func allGiftsSignal(context: AccountContext) -> Signal<[KWGramPhantomGift], NoError> {
        return context.account.postbox.preferencesView(keys: [KWGramPreferencesKeys.phantomGifts])
        |> map { view -> [KWGramPhantomGift] in
            let gifts = view.values[KWGramPreferencesKeys.phantomGifts]?.get(KWGramPhantomGiftList.self)?.gifts ?? []
            return gifts.sorted(by: { $0.date > $1.date })
        }
    }

    /// Live list of local visual gifts assigned to a profile. The recipient profile is
    /// selected by `peerId`; if omitted, it is the account owner's own profile. These
    /// records live only in the local Postbox and are never sent to Telegram.
    public static func profileGiftsSignal(context: AccountContext, peerId: EnginePeer.Id? = nil) -> Signal<[KWGramPhantomGift], NoError> {
        let profilePeerId = peerId ?? context.account.peerId
        return self.allGiftsSignal(context: context)
        |> map { gifts -> [KWGramPhantomGift] in
            return gifts
                .filter { $0.peerId == profilePeerId && $0.savedToProfile }
                .sorted { lhs, rhs in
                    if lhs.pinnedToTop != rhs.pinnedToTop {
                        return lhs.pinnedToTop
                    }
                    return lhs.date > rhs.date
                }
        }
    }

    public static func gift(transaction: Transaction, id: Int64) -> KWGramPhantomGift? {
        return self.allGifts(transaction: transaction).first(where: { $0.id == id })
    }

    public static func marketGiftsSignal(context: AccountContext) -> Signal<[KWGramPhantomGift], NoError> {
        return self.allGiftsSignal(context: context)
        |> map { gifts in
            gifts.filter { $0.marketPrice != nil && $0.soldDate == nil }
                .sorted { ($0.marketListedAt ?? 0) > ($1.marketListedAt ?? 0) }
        }
    }

    public static func wornGiftSignal(context: AccountContext) -> Signal<KWGramPhantomGift?, NoError> {
        let selfPeerId = context.account.peerId
        return self.allGiftsSignal(context: context)
        |> map { gifts in
            gifts.first(where: { $0.peerId == selfPeerId && $0.worn && $0.soldDate == nil })
        }
    }

}
