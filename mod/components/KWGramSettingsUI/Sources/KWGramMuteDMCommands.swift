import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import KWGramCore

/// Единицы длительности — как в Android-плагине `mute_ls`: `s/m/h/d/w` в секундах.
private let kwGramMuteDMUnits: [Character: Int64] = [
    "s": 1,
    "m": 60,
    "h": 3_600,
    "d": 86_400,
    "w": 604_800
]

/// Разбирает «1h», «30m», «2h 30m», «1d» — как плагин: все пары «цифры + единица»
/// суммируются, посторонние символы в строке — ошибка, чисто цифровая строка — минуты,
/// пустая — `nil` (вызывающий трактует это как «навсегда» либо как ошибку настройки).
/// Результат ограничивается `Int32.max` секундами — переполнение при вводе мусора
/// не должно ронять приложение.
private func kwGramMuteDMParseDuration(_ text: String) -> Int32? {
    let text = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if text.isEmpty {
        return nil
    }

    var total: Int64 = 0
    var found = false
    if let regex = try? NSRegularExpression(pattern: "(\\d+)\\s*([smhdw])") {
        let nsText = text as NSString
        for match in regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)) {
            guard match.numberOfRanges == 3,
                  let numberValue = Int64(nsText.substring(with: match.range(at: 1))),
                  let unit = nsText.substring(with: match.range(at: 2)).first,
                  let unitSeconds = kwGramMuteDMUnits[unit]
            else {
                continue
            }
            total += numberValue * unitSeconds
            found = true
        }
    }

    // Как в плагине: всё, что не цифра/пробел и не единица из набора, — неверный формат.
    var leftover = text.replacingOccurrences(of: "[0-9\\s]", with: "", options: .regularExpression)
    leftover = leftover.replacingOccurrences(of: "[smhdw]", with: "", options: .regularExpression)
    if !leftover.isEmpty {
        return nil
    }

    if !found {
        // «Чисто цифровая строка» плагин трактует как минуты: `!mute 30` == `!mute 30m`.
        guard let minutes = Int64(text) else {
            return nil
        }
        total = minutes * 60
    }
    guard total > 0 else {
        return nil
    }
    return Int32(min(total, Int64(Int32.max)))
}

/// Формат «до 14.10 18:00» — строка подсказок команд и метка списка в настройках.
func kwGramMuteDMFormatUntil(_ until: Int32) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    formatter.dateFormat = "dd.MM HH:mm"
    return formatter.string(from: Date(timeIntervalSince1970: TimeInterval(until)))
}

private func kwGramMuteDMTitle(transaction: Transaction, peerId: PeerId) -> String {
    if let peer = transaction.getPeer(peerId) {
        return EnginePeer(peer).compactDisplayTitle
    }
    return "id \(peerId.id)"
}

/// Перехватывает текст, набранный в чате: если первым токеном идёт настроенная команда
/// мьюта/размьюта — применяет её и через `onResult` отдаёт текст подсказки (её показывает
/// ChatController, он же чистит поле ввода). `true` — команда поглощена, отправки не будет;
/// `false` — это не команда, сообщение уходит как обычно.
///
/// Как в плагине: работает только в личных чатах; в группах/каналах/Избранном совпавшая
/// команда тоже поглощается, но с ошибкой «Мут работает только в личных чатах.» — чтобы
/// служебный текст не улетел собеседникам.
public func kwGramMuteDMHandleCommand(context: AccountContext, peerId: PeerId, text: String, onResult: @escaping (String) -> Void) -> Bool {
    guard let config = KWGramMuteDMRuntime.shared.config(accountKey: context.account.peerId.toInt64()), config.enabled else {
        return false
    }

    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
    guard let first = parts.first else {
        return false
    }
    let firstToken = String(first).lowercased()
    let isMute = !config.muteCommand.isEmpty && firstToken == config.muteCommand.lowercased()
    let isUnmute = !config.unmuteCommand.isEmpty && firstToken == config.unmuteCommand.lowercased()
    guard isMute || isUnmute else {
        return false
    }
    let argument = parts.count > 1 ? String(parts[1]) : ""

    guard peerId.namespace == Namespaces.Peer.CloudUser, peerId != context.account.peerId else {
        onResult(isMute ? "Мут работает только в личных чатах." : "Размутить можно только в личном чате.")
        return true
    }

    let postbox = context.account.postbox
    let now = Int32(Date().timeIntervalSince1970)

    if isMute {
        // Без аргумента — длительность из настроек; пустая настройка — «навсегда»,
        // неразборчивая — ошибка (как плагин с `duration_text` из настроек).
        let durationText = argument.isEmpty ? config.defaultDuration : argument
        if !durationText.isEmpty {
            guard let seconds = kwGramMuteDMParseDuration(durationText) else {
                onResult("Неверный формат времени. Примеры: 30m, 2h, 1d.")
                return true
            }
            let until = Int32(min(Int64(now) + Int64(seconds), Int64(Int32.max)))
            let _ = (postbox.transaction { transaction -> String in
                let title = kwGramMuteDMTitle(transaction: transaction, peerId: peerId)
                KWGramMutedPeerStore.set(transaction: transaction, peerId: peerId, mutedAt: now, until: until)
                return "Замутил \(title) до \(kwGramMuteDMFormatUntil(until))"
            }
            |> deliverOnMainQueue).start(next: onResult)
            return true
        }

        let _ = (postbox.transaction { transaction -> String in
            let title = kwGramMuteDMTitle(transaction: transaction, peerId: peerId)
            KWGramMutedPeerStore.set(transaction: transaction, peerId: peerId, mutedAt: now, until: nil)
            return "Замутил \(title) навсегда"
        }
        |> deliverOnMainQueue).start(next: onResult)
        return true
    }

    // Размут.
    let _ = (postbox.transaction { transaction -> String in
        let title = kwGramMuteDMTitle(transaction: transaction, peerId: peerId)
        if KWGramMutedPeerStore.remove(transaction: transaction, peerId: peerId) {
            return "Размутил \(title)"
        }
        return "Этот пользователь не в муте."
    }
    |> deliverOnMainQueue).start(next: onResult)
    return true
}
