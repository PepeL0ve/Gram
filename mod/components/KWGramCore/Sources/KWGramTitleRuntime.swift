import Foundation
import Postbox
import SwiftSignalKit

/// Снимок пользовательского заголовка главного экрана («Заголовок», раздел «Чаты») для
/// одного аккаунта: `ChatListController` строит заголовок синхронно при построении лейаута
/// (шапка навигации + вкладка «Чаты»), поэтому значение зеркалится в память. Стартует один
/// раз на аккаунт из `AccountContextImpl` (патч), обновляется живой подпиской на
/// `rawSettingsSignal` — как `KWGramMuteDMRuntime`.
///
/// Два способа чтения:
///   • `title(accountKey:)` — синхронное значение для точек построения заголовка;
///   • `titleSignal(accountKey:)` — живой сигнал (с `distinctUntilChanged`), чтобы
///     контроллер обновлял уже построенный заголовок при смене значения в настройках.
public final class KWGramTitleRuntime {
    public static let shared = KWGramTitleRuntime()

    private let lock = NSLock()
    private var titles: [Int64: String] = [:]
    private var promises: [Int64: ValuePromise<String?>] = [:]
    private var startedAccounts: Set<Int64> = []
    private var disposables: [Int64: Disposable] = [:]

    private init() {
    }

    /// Пользовательский заголовок главного экрана или `nil`, если не задан / ещё не прогрет —
    /// вызывающий в этом случае оставляет стандартный «Чаты».
    public func title(accountKey: Int64) -> String? {
        self.lock.lock()
        defer { self.lock.unlock() }
        guard let title = self.titles[accountKey] else {
            return nil
        }
        return title.isEmpty ? nil : title
    }

    /// Живой сигнал пользовательского заголовка (`nil` = стандартный «Чаты»).
    public func titleSignal(accountKey: Int64) -> Signal<String?, NoError> {
        let promise = self.promise(accountKey: accountKey)
        return promise.get() |> distinctUntilChanged
    }

    public func start(accountKey: Int64, postbox: Postbox) {
        self.lock.lock()
        if self.startedAccounts.contains(accountKey) {
            self.lock.unlock()
            return
        }
        self.startedAccounts.insert(accountKey)
        self.lock.unlock()

        let promise = self.promise(accountKey: accountKey)

        // rawSettingsSignal: «Заголовок» — косметика раздела «Чаты», masterEnabled-гейт
        // на неё не наложен.
        let disposable = (KWGramCore.rawSettingsSignal(postbox: postbox)
        |> deliverOn(Queue.concurrentDefaultQueue())).start(next: { [weak self] settings in
            guard let self else {
                return
            }
            self.lock.lock()
            self.titles[accountKey] = settings.mainScreenTitle
            self.lock.unlock()
            promise.set(settings.mainScreenTitle.isEmpty ? nil : settings.mainScreenTitle)
        })

        self.lock.lock()
        self.disposables[accountKey] = disposable
        self.lock.unlock()
    }

    private func promise(accountKey: Int64) -> ValuePromise<String?> {
        self.lock.lock()
        defer { self.lock.unlock() }
        if let promise = self.promises[accountKey] {
            return promise
        }
        let promise = ValuePromise<String?>(self.titles[accountKey].flatMap { $0.isEmpty ? nil : $0 }, ignoreRepeated: true)
        self.promises[accountKey] = promise
        return promise
    }
}
