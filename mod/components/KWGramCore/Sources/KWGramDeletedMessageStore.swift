import Foundation
import Postbox
import SwiftSignalKit

private struct KWGramDeletedMessageList: Codable {
    var messages: [KWGramDeletedMessage]
}

/// Persistent, entirely local storage for the anti-delete feature's captured messages.
/// Backed by Postbox's own `PreferencesEntry` mechanism under the mod's reserved key range,
/// same as `KWGramCore`'s settings and `PhantomGiftKit`'s gift list — survives app restarts
/// for free, never touches `account.network`.
public enum KWGramDeletedMessageStore {
    public static func all(transaction: Transaction) -> [KWGramDeletedMessage] {
        return transaction.getPreferencesEntry(key: KWGramPreferencesKeys.deletedMessages)?.get(KWGramDeletedMessageList.self)?.messages ?? []
    }

    public static func add(transaction: Transaction, message: KWGramDeletedMessage) {
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.deletedMessages, { entry in
            var list = entry?.get(KWGramDeletedMessageList.self) ?? KWGramDeletedMessageList(messages: [])
            list.messages.append(message)
            return PreferencesEntry(list)
        })
    }

    public static func remove(transaction: Transaction, id: Int64) {
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.deletedMessages, { entry in
            var list = entry?.get(KWGramDeletedMessageList.self) ?? KWGramDeletedMessageList(messages: [])
            list.messages.removeAll(where: { $0.id == id })
            return PreferencesEntry(list)
        })
    }

    @discardableResult
    public static func removeAll(transaction: Transaction) -> [KWGramDeletedMessage] {
        let existing = self.all(transaction: transaction)
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.deletedMessages, { _ in
            return PreferencesEntry(KWGramDeletedMessageList(messages: []))
        })
        return existing
    }

    /// Live list of every captured message on this device, newest-deleted first.
    public static func allSignal(postbox: Postbox) -> Signal<[KWGramDeletedMessage], NoError> {
        return postbox.preferencesView(keys: [KWGramPreferencesKeys.deletedMessages])
        |> map { view -> [KWGramDeletedMessage] in
            let messages = view.values[KWGramPreferencesKeys.deletedMessages]?.get(KWGramDeletedMessageList.self)?.messages ?? []
            return messages.sorted(by: { $0.deletedAt > $1.deletedAt })
        }
    }
}
