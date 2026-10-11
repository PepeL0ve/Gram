import Foundation
import SwiftSignalKit
import Postbox

/// KW Gram "Персональные цвета": the user's own name colour (what colours their name in every
/// chat and in their profile header) and profile colour (what colours the profile page).
///
/// This module is storage only — it remembers the chosen colours. Applying them to the real
/// account is done by the engine at runtime, driven by `AccountContext` through
/// `KWGramPersonalColorRuntime` (see the patch), because `KWGramCore` deliberately depends on
/// neither TelegramCore nor AccountContext.
///
/// A colour is stored as its raw `PeerNameColor` index (0=red, 1=orange, 2=violet, 3=green,
/// 4=cyan, 5=blue, 6=pink) — the same indices Telegram uses, so the runtime can pass them
/// straight to `engine.accountData.updateNameColorAndEmoji`.
public struct KWGramPersonalColors: Codable, Equatable {
    /// Raw `PeerNameColor` index for the name colour, or nil when not set.
    public var nameColorIndex: Int32?
    /// Raw `PeerNameColor` index for the profile background colour, or nil when not set.
    public var profileColorIndex: Int32?

    public init(nameColorIndex: Int32? = nil, profileColorIndex: Int32? = nil) {
        self.nameColorIndex = nameColorIndex
        self.profileColorIndex = profileColorIndex
    }
}

public enum KWGramPersonalColorStore {
    public static let key = KWGramPreferencesKeys.personalColors

    public static func read(transaction: Transaction) -> KWGramPersonalColors {
        return transaction.getPreferencesEntry(key: key)?.get(KWGramPersonalColors.self) ?? KWGramPersonalColors()
    }

    public static func write(transaction: Transaction, colors: KWGramPersonalColors) {
        transaction.setPreferencesEntry(key: key, value: PreferencesEntry(colors))
    }

    public static func update(transaction: Transaction, _ f: (KWGramPersonalColors) -> KWGramPersonalColors) {
        write(transaction: transaction, colors: f(read(transaction: transaction)))
    }

    public static func signal(postbox: Postbox) -> Signal<KWGramPersonalColors, NoError> {
        return postbox.preferencesView(keys: [key])
        |> map { view -> KWGramPersonalColors in
            return view.values[key]?.get(KWGramPersonalColors.self) ?? KWGramPersonalColors()
        }
        |> distinctUntilChanged
    }

    public static func updateInteractively(postbox: Postbox, _ f: @escaping (KWGramPersonalColors) -> KWGramPersonalColors) -> Signal<Never, NoError> {
        return postbox.transaction { transaction -> Void in
            update(transaction: transaction, f)
        }
        |> ignoreValues
    }
}
