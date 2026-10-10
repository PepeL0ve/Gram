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
/// Lives in KWGramCore (no TelegramCore import) — the actual name write is injected as an
/// `updateName` closure so the caller (TelegramUI's AccountContext hook, which owns the
/// engine) supplies `engine.accountData.updateAccountPeerName`.
public enum KWGramTimeInNicknameRuntime {
    public static func observe(postbox: Postbox, peerId: PeerId, updateName: @escaping (String, String) -> Signal<Void, NoError>) -> Disposable {
        let session = Session(postbox: postbox, peerId: peerId, updateName: updateName)
        return ActionDisposable {
            session.shutdown()
        }
    }

    private final class Session {
        private let postbox: Postbox
        private let peerId: PeerId
        private let updateName: (String, String) -> Signal<Void, NoError>
        private let settingsDisposable: Disposable?
        private var timer: Timer?
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

        init(postbox: Postbox, peerId: PeerId, updateName: @escaping (String, String) -> Signal<Void, NoError>) {
            self.postbox = postbox
            self.peerId = peerId
            self.updateName = updateName
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
            let timer = Timer(fire: now.addingTimeInterval(delay), interval: interval, repeats: true, block: { [weak self] _ in
                self?.tick()
            })
            timer.tolerance = 0.5
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        private func captureBackupIfNeeded() {
            let peerId = self.peerId
            let postbox = self.postbox
            let _ = postbox.transaction { transaction -> Void in
                guard KWGramCore.rawSettings(transaction: transaction).timeInNicknameBackupLastName == nil, let user = transaction.getPeer(peerId) as? TelegramUser else {
                    return
                }
                KWGramCore.updateSettings(transaction: transaction, { settings in
                    var settings = settings
                    settings.timeInNicknameBackupLastName = user.lastName
                    return settings
                })
            }.start()
        }

        private func restoreBackupIfNeeded() {
            guard !self.updateInFlight else {
                return
            }
            let postbox = self.postbox
            let peerId = self.peerId
            let updateName = self.updateName
            self.updateInFlight = true
            let _ = (postbox.transaction { transaction -> (String, String)? in
                guard let backup = KWGramCore.rawSettings(transaction: transaction).timeInNicknameBackupLastName, let user = transaction.getPeer(peerId) as? TelegramUser else {
                    return nil
                }
                return (user.firstName, backup)
            }
            |> deliverOnMainQueue).start(next: { [weak self] names in
                guard let self else {
                    return
                }
                guard let (firstName, lastName) = names else {
                    self.updateInFlight = false
                    return
                }
                let _ = updateName(firstName, lastName).start(completed: { [weak self] in
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
        }

        private func tick() {
            guard self.enabled, !self.stopped, !self.updateInFlight else {
                return
            }
            let timeString = Session.mskFormatter.string(from: Date())
            let postbox = self.postbox
            let peerId = self.peerId
            let updateName = self.updateName
            self.updateInFlight = true
            let _ = (postbox.transaction { transaction -> (String, String)? in
                guard let user = transaction.getPeer(peerId) as? TelegramUser else {
                    return nil
                }
                return (user.firstName, user.lastName)
            }
            |> deliverOnMainQueue).start(next: { [weak self] names in
                guard let self else {
                    return
                }
                if let (firstName, lastName) = names, lastName != timeString, !self.stopped {
                    let _ = updateName(firstName, timeString).start(completed: { [weak self] in
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
