import Foundation
import Postbox
import SwiftSignalKit

/// Снимок настроек команд «Мут ЛС» для одного аккаунта: ChatController должен решить
/// *синхронно*, перехватывать ли вводимый текст (сообщение либо уходит, либо нет — ждать
/// асинхронное чтение Postbox нельзя), поэтому настройки зеркалируются в память. Стартует
/// один раз на аккаунт из `AccountContextImpl` (патч), обновляется живой подпиской на
/// `rawSettingsSignal` — как `KWGramFakeAdminRuntime`.
public struct KWGramMuteDMCommandConfig: Equatable {
    public var enabled: Bool
    public var muteCommand: String
    public var unmuteCommand: String
    public var defaultDuration: String

    public init(enabled: Bool, muteCommand: String, unmuteCommand: String, defaultDuration: String) {
        self.enabled = enabled
        self.muteCommand = muteCommand
        self.unmuteCommand = unmuteCommand
        self.defaultDuration = defaultDuration
    }
}

public final class KWGramMuteDMRuntime {
    public static let shared = KWGramMuteDMRuntime()

    private let lock = NSLock()
    private var configs: [Int64: KWGramMuteDMCommandConfig] = [:]
    private var startedAccounts: Set<Int64> = []
    private var disposables: [Int64: Disposable] = [:]

    private init() {
    }

    /// `nil` до прогрева стартовой подписки — вызывающий в этом случае просто не
    /// перехватывает текст (до первого кадра после запуска настройки читаются «вслепую»).
    public func config(accountKey: Int64) -> KWGramMuteDMCommandConfig? {
        self.lock.lock()
        defer { self.lock.unlock() }
        return self.configs[accountKey]
    }

    public func start(accountKey: Int64, postbox: Postbox) {
        self.lock.lock()
        if self.startedAccounts.contains(accountKey) {
            self.lock.unlock()
            return
        }
        self.startedAccounts.insert(accountKey)
        self.lock.unlock()

        // rawSettingsSignal, а не settingsSignal: «Мут ЛС» — фича раздела «Чаты», её
        // выключение «Визуальную галку» masterEnabled касаться не должна (как Gift Search).
        let disposable = (KWGramCore.rawSettingsSignal(postbox: postbox)
        |> deliverOn(Queue.concurrentDefaultQueue())).start(next: { [weak self] settings in
            guard let self else {
                return
            }
            let config = KWGramMuteDMCommandConfig(
                enabled: settings.muteDmEnabled,
                muteCommand: settings.muteDmCommand,
                unmuteCommand: settings.muteDmUnmuteCommand,
                defaultDuration: settings.muteDmDefaultDuration
            )
            self.lock.lock()
            self.configs[accountKey] = config
            self.lock.unlock()
        })

        self.lock.lock()
        self.disposables[accountKey] = disposable
        self.lock.unlock()
    }
}
