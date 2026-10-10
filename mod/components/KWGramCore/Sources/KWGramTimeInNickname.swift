import Foundation
import SwiftSignalKit
import Postbox

/// One account's live "Время в ник" session — the KW Gram feature that, unlike everything
/// else in the mod, edits real Telegram state: while `timeInNicknameEnabled` is on, the
/// account's real last name is kept showing the current Moscow time in "HH:mm" format,
/// rewritten once a minute (aligned to the minute boundary). The pre-enable last name is
/// captured into `timeInNicknameBackupLastName` on the off→on transition and restored,
/// with the backup cleared, when the setting turns off again.
///
/// Lives in KWGramCore (no TelegramCore import) — reading the account's current names and
/// writing them is injected by the caller (TelegramUI's AccountContext hook, which owns the
/// engine and TelegramUser).
public enum KWGramTimeInNicknameRuntime {
    public static func observe(postbox: Postbox, readNames: @escaping () -> Signal<(String, String)?, NoError>, writeName: @escaping (String, String) -> Signal<Void, NoError>) -> Disposable {
        let session = Session(postbox: postbox, readNames: readNames, writeName: writeName)
        return ActionDisposable {
            session.shutdown()
        }
    }

    private final class Session {
        private let postbox: Postbox
        private let readNames: () -> Signal<(String, String)?, NoError>
        private let writeName: (String, String) -> Signal<Void, NoError>
        private var settingsDisposable: Disposable?
        private var timer: Foundation.Timer?
        private var lastEnabled: Bool?
        private var updateInFlight = false
        private var stopped = false

        private static let mskFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "Europe/Moscow")
            formatter.dateFormat = "HH:mm"
            return formatter
        }()

        init(postbox: Postbox, readNames: @escaping () -> Signal<(String, String)?, NoError>, writeName: @escaping (String, String) -> Signal<Void, NoError>) {
            self.postbox = postbox
            self.readNames = readNames
            self.writeName = writeName
            self.settingsDisposable = nil
            self.settingsDisposable = (KWGramCore.rawSettingsSignal(postbox: postbox)
            |> deliverOnMainQueue).start(next: { [weak self] settings in
                self?.apply(enabled: settings.timeInNicknameEnabled)
            })
        }

        func shutdown() {
            self.stopped = true
            self.timer?.invalidate()
            self.timer = nil
            self.settingsDisposable?.dispose()
        }

        private func apply(enabled: Bool) {
            if self.stopped {
                return
            }
            let transitioned = self.lastEnabled != enabled
            self.lastEnabled = enabled
            if enabled {
                if transitioned {
                    self.captureBackupIfNeeded()
                }
                self.scheduleTimer()
                self.tick()
            } else {
                self.timer?.invalidate()
                self.timer = nil
                self.restoreBackupIfNeeded()
            }
        }

        /// Fires the first update at the next whole minute, then every minute after that —
        /// so the displayed time flips exactly when the displayed minute does.
        private func scheduleTimer() {
            guard self.timer == nil else {
                return
            }
            let interval: TimeInterval = 60.0
            let now = Date()
            let delay = interval - now.timeIntervalSince1970.truncatingRemainder(dividingBy: interval)
            let timer = Foundation.Timer(fire: now.addingTimeInterval(delay), interval: interval, repeats: true, block: { [weak self] _ in
                self?.tick()
            })
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        private func captureBackupIfNeeded() {
            let postbox = self.postbox
            let readNames = self.readNames
            let _ = (readNames()
            |> deliverOnMainQueue).start(next: { names in
                guard let (_, lastName) = names else {
                    return
                }
                let _ = postbox.transaction { transaction -> Void in
                    guard KWGramCore.rawSettings(transaction: transaction).timeInNicknameBackupLastName == nil else {
                        return
                    }
                    KWGramCore.updateSettings(transaction: transaction, { settings in
                        var settings = settings
                        settings.timeInNicknameBackupLastName = lastName
                        return settings
                    })
                }.start()
            })
        }

        private func restoreBackupIfNeeded() {
            guard !self.updateInFlight else {
                return
            }
            let postbox = self.postbox
            let readNames = self.readNames
            let writeName = self.writeName
            self.updateInFlight = true
            let _ = (postbox.transaction { transaction -> String? in
                return KWGramCore.rawSettings(transaction: transaction).timeInNicknameBackupLastName
            }
            |> deliverOnMainQueue).start(next: { [weak self] backup in
                guard let self else {
                    return
                }
                guard let backup else {
                    self.updateInFlight = false
                    return
                }
                let _ = (readNames()
                |> deliverOnMainQueue).start(next: { [weak self] names in
                    guard let self else {
                        return
                    }
                    guard let (firstName, _) = names else {
                        self.updateInFlight = false
                        return
                    }
                    let _ = writeName(firstName, backup).start(completed: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.updateInFlight = false
                        let _ = postbox.transaction { transaction -> Void in
                            KWGramCore.updateSettings(transaction: transaction, { settings in
                                var settings = settings
                                settings.timeInNicknameBackupLastName = nil
                                return settings
                            })
                        }.start()
                    })
                })
            })
        }

        private func tick() {
            guard self.enabled, !self.stopped, !self.updateInFlight else {
                return
            }
            let timeString = Session.mskFormatter.string(from: Date())
            let readNames = self.readNames
            let writeName = self.writeName
            self.updateInFlight = true
            let _ = (readNames()
            |> deliverOnMainQueue).start(next: { [weak self] names in
                guard let self else {
                    return
                }
                if let (firstName, lastName) = names, lastName != timeString, !self.stopped {
                    let _ = writeName(firstName, timeString).start(completed: { [weak self] in
                        self?.updateInFlight = false
                    })
                } else {
                    self.updateInFlight = false
                }
            })
        }

        private var enabled: Bool {
            return self.lastEnabled == true
        }
    }
}
