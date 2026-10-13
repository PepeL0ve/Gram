import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

/// One tappable row of the «Подарки» search tab.
public struct KWGramGiftSearchRow {
    public enum Kind {
        /// Opens the gift's details screen.
        case gift(StarGift)
        /// Dives into one of this account's own gift collections.
        case collection(Int32)
        /// Returns from a collection back to the top-level list.
        case back
    }

    /// Stable identity, shared with `ChatListSearchEntryStableId.kwGiftSearch`.
    public let id: String
    public let title: String
    public let label: String
    public let kind: Kind

    public init(id: String, title: String, label: String, kind: Kind) {
        self.id = id
        self.title = title
        self.label = label
        self.kind = kind
    }
}

/// Data half of KW Gram's «Подарки» search tab («Чаты» → «Поиск подарков»).
///
/// Top level: the account's own gift collections (`ProfileGiftsCollectionsContext`, cached
/// per account — the context refreshes itself on first creation) followed by the gift
/// catalog (`engine.payments.cachedStarGifts()`, fetched once when nothing is cached yet).
/// Inside a collection: that collection's gifts, with a back row first.
///
/// Matching mirrors the downloads tab: Postbox index tokens with combined transliteration,
/// so Russian and Latin spellings of the same name both hit. An empty query shows
/// everything (the catalog capped at 60 rows to keep the first paint cheap).
public enum KWGramGiftSearch {
    private static let collectionsLock = NSLock()
    private static var collectionsContexts: [PeerId: ProfileGiftsCollectionsContext] = [:]

    private static let catalogRowLimit = 60

    public static func rows(context: AccountContext, query: String, selectedCollectionId: Int32?) -> Signal<[KWGramGiftSearchRow], NoError> {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let selectedCollectionId {
            return self.collectionRows(context: context, collectionId: selectedCollectionId, query: trimmedQuery)
        }
        return self.topLevelRows(context: context, query: trimmedQuery)
    }

    // MARK: - Top level: own collections + catalog gifts

    private static func topLevelRows(context: AccountContext, query: String) -> Signal<[KWGramGiftSearchRow], NoError> {
        let tokens = stringIndexTokens(query, transliteration: .combined)
        return combineLatest(
            self.collectionsState(context: context),
            self.catalogGifts(context: context)
        )
        |> map { collections, gifts -> [KWGramGiftSearchRow] in
            var rows: [KWGramGiftSearchRow] = []

            for collection in collections {
                if !tokens.isEmpty && !self.matches(collection.title, tokens: tokens) {
                    continue
                }
                rows.append(KWGramGiftSearchRow(
                    id: "collection-\(collection.id)",
                    title: collection.title,
                    label: "\(collection.count)",
                    kind: .collection(collection.id)
                ))
            }

            var displayedCount = 0
            for giftValue in gifts {
                if displayedCount >= self.catalogRowLimit {
                    break
                }
                let row = self.giftRow(giftValue)
                if !tokens.isEmpty && !self.matches(row.title, tokens: tokens) {
                    continue
                }
                rows.append(row)
                displayedCount += 1
            }
            return rows
        }
    }

    /// The cached gift catalog; fetches it (one-shot) the first time only.
    private static func catalogGifts(context: AccountContext) -> Signal<[StarGift], NoError> {
        return context.engine.payments.cachedStarGifts()
        |> take(1)
        |> mapToSignal { cached -> Signal<[StarGift], NoError> in
            if let cached, !cached.isEmpty {
                return .single(cached)
            }
            // Nothing cached yet (the user never opened a gifts screen): run the one-shot
            // catalog update, then re-read the cache once the update has completed. Built
            // explicitly because `then` needs matching element types and the update signal
            // is `Signal<Never>` (it emits nothing, only completes).
            return Signal<[StarGift], NoError> { subscriber in
                let disposable = MetaDisposable()
                disposable.set(context.engine.payments.keepStarGiftsUpdated().start(next: { _ in
                }, completed: {
                    disposable.set(context.engine.payments.cachedStarGifts().start(next: { value in
                        subscriber.putNext(value ?? [])
                    }, completed: {
                        subscriber.putCompletion()
                    }))
                }))
                return disposable
            }
        }
    }

    // MARK: - One collection's gifts

    private static func collectionRows(context: AccountContext, collectionId: Int32, query: String) -> Signal<[KWGramGiftSearchRow], NoError> {
        let tokens = stringIndexTokens(query, transliteration: .combined)
        let giftsContext = self.collectionsContext(context: context).giftsContextForCollection(id: collectionId)
        return giftsContext.state
        |> map { state -> [KWGramGiftSearchRow] in
            var rows: [KWGramGiftSearchRow] = [
                KWGramGiftSearchRow(id: "back", title: "← Назад", label: "", kind: .back)
            ]
            for entry in state.gifts {
                let row = self.giftRow(entry.gift)
                if !tokens.isEmpty && !self.matches(row.title, tokens: tokens) {
                    continue
                }
                rows.append(row)
            }
            return rows
        }
    }

    // MARK: - Helpers

    private static func giftRow(_ giftValue: StarGift) -> KWGramGiftSearchRow {
        switch giftValue {
        case let .generic(gift):
            return KWGramGiftSearchRow(
                id: "gift-\(gift.id)",
                title: gift.title ?? "Подарок",
                label: "⭐️ \(gift.price)",
                kind: .gift(giftValue)
            )
        case let .unique(gift):
            return KWGramGiftSearchRow(
                id: "ugift-\(gift.id)",
                title: gift.title,
                label: "№ \(gift.number)",
                kind: .gift(giftValue)
            )
        }
    }

    private static func matches(_ text: String, tokens: [ValueBoxKey]) -> Bool {
        return matchStringIndexTokens(stringIndexTokens(text, transliteration: .none), with: tokens)
    }

    /// One collections context per account: its initial fetch is shared by every keystroke
    /// instead of being repeated per query, and its per-collection gift contexts are cached
    /// inside it too. `init` kicks off the first load (cache first, then network).
    private static func collectionsContext(context: AccountContext) -> ProfileGiftsCollectionsContext {
        let accountPeerId = context.account.peerId

        self.collectionsLock.lock()
        if let existing = self.collectionsContexts[accountPeerId] {
            self.collectionsLock.unlock()
            return existing
        }
        let created = ProfileGiftsCollectionsContext(account: context.account, peerId: accountPeerId, allGiftsContext: nil)
        self.collectionsContexts[accountPeerId] = created
        self.collectionsLock.unlock()
        return created
    }

    private static func collectionsState(context: AccountContext) -> Signal<[StarGiftCollection], NoError> {
        return self.collectionsContext(context: context).state
        |> map { $0.collections }
    }
}
