import Foundation
import Postbox
import SwiftSignalKit

/// One private-chat peer that KW Gram "Мут ЛС" currently mutes: when it was muted and when
/// (or whether) the mute expires. `until == nil` — навсегда.
///
/// Stored in its own preferences key rather than inside `KWGramSettings`: unlike a
/// configuration flag this is dynamic per-peer data that only grows while the feature is
/// used, and the incoming-message filter reads it on every applied update batch — a small
/// dedicated list keeps that read trivial and the settings struct unchanged.
public struct KWGramMutedPeer: Codable, Equatable {
    public var peerId: PeerId
    /// Момент мьюта в секундах (локальное время, как в Android-плагине): сообщения
    /// собеседника, отправленные *до* этого момента, не трогаются — мьют удаляет только
    /// новые.
    public var mutedAt: Int32
    /// До каких пор (секунды, локальное время); `nil` — навсегда.
    public var until: Int32?

    public init(peerId: PeerId, mutedAt: Int32, until: Int32?) {
        self.peerId = peerId
        self.mutedAt = mutedAt
        self.until = until
    }
}

private struct KWGramMutedPeerList: Codable {
    var peers: [KWGramMutedPeer]
}

public enum KWGramMutedPeerStore {
    public static func all(transaction: Transaction) -> [KWGramMutedPeer] {
        return transaction.getPreferencesEntry(key: KWGramPreferencesKeys.mutedPeers)?.get(KWGramMutedPeerList.self)?.peers ?? []
    }

    /// Муты, которые ещё не истекли на момент `now`, — новые первыми. Истёкшие записи
    /// остаются в хранилище до следующей записи (`set` чистит их); чистое чтение
    /// намеренно не пишет в Postbox.
    public static func active(transaction: Transaction, now: Int32) -> [KWGramMutedPeer] {
        return self.all(transaction: transaction)
            .filter { entry in
                guard let until = entry.until else {
                    return true
                }
                return now < until
            }
            .sorted { $0.mutedAt > $1.mutedAt }
    }

    /// То, что читает `KWGramMuteDMFilter` на каждом батче входящих: peerId → момент
    /// мьюта. Пустой словарь — фильтру нечего делать (быстрый выход без разбора остальных
    /// сообщений).
    public static func activeMutedAt(transaction: Transaction, now: Int32) -> [PeerId: Int32] {
        var result: [PeerId: Int32] = [:]
        for entry in self.active(transaction: transaction, now: now) {
            result[entry.peerId] = entry.mutedAt
        }
        return result
    }

    public static func state(transaction: Transaction, peerId: PeerId) -> KWGramMutedPeer? {
        return self.all(transaction: transaction).first(where: { $0.peerId == peerId })
    }

    /// Включает (или перезаписывает) мут; заодно выкидывает истёкшие записи — единственное
    /// место, где список пишется, поэтому «мусор» не копится.
    public static func set(transaction: Transaction, peerId: PeerId, mutedAt: Int32, until: Int32?) {
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.mutedPeers, { entry in
            var list = entry?.get(KWGramMutedPeerList.self) ?? KWGramMutedPeerList(peers: [])
            list.peers.removeAll(where: { entry in
                if let entryUntil = entry.until, Int32(Date().timeIntervalSince1970) >= entryUntil {
                    return true
                }
                return false
            })
            list.peers.removeAll(where: { $0.peerId == peerId })
            list.peers.append(KWGramMutedPeer(peerId: peerId, mutedAt: mutedAt, until: until))
            return PreferencesEntry(list)
        })
    }

    /// Убирает из мьюта; `true` — собеседник действительно был в муте (для текста
    /// подсказки «Размутил» vs «не в муте»).
    @discardableResult
    public static func remove(transaction: Transaction, peerId: PeerId) -> Bool {
        var removed = false
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.mutedPeers, { entry in
            guard var list = entry?.get(KWGramMutedPeerList.self), list.peers.contains(where: { $0.peerId == peerId }) else {
                return entry
            }
            list.peers.removeAll(where: { $0.peerId == peerId })
            removed = true
            return PreferencesEntry(list)
        })
        return removed
    }

    /// Live список для экрана настроек (см. `KWGramMessagesSettingsScreen`).
    public static func allSignal(postbox: Postbox) -> Signal<[KWGramMutedPeer], NoError> {
        return postbox.preferencesView(keys: [KWGramPreferencesKeys.mutedPeers])
        |> map { view -> [KWGramMutedPeer] in
            return view.values[KWGramPreferencesKeys.mutedPeers]?.get(KWGramMutedPeerList.self)?.peers ?? []
        }
        |> distinctUntilChanged
    }
}
