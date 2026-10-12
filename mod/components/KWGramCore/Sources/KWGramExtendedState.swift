import Foundation
import Postbox
import SwiftSignalKit

/// Raw-string enums are stored inside `PreferencesEntry`. They must use a keyed
/// `Codable` representation: Telegram's Postbox encoder deliberately has no
/// `singleValueContainer`, which is what Swift otherwise synthesizes for a raw enum.
public enum KWGramLocalCurrency: String, CaseIterable {
    case stars
    case ton
    case rubles

    public var displayName: String {
        switch self {
        case .stars: return "Stars"
        case .ton: return "TON"
        case .rubles: return "Рубли"
        }
    }
}

extension KWGramLocalCurrency: Codable {
    private enum CodingKeys: String, CodingKey {
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .value)
        self = KWGramLocalCurrency(rawValue: rawValue) ?? .stars
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .value)
    }
}

public enum KWGramLocalOperationKind: String, CaseIterable {
    case topUp
    case purchase
    case sale
    case transfer
    case debit
    case credit

    public var displayName: String {
        switch self {
        case .topUp: return "Пополнение"
        case .purchase: return "Покупка"
        case .sale: return "Продажа"
        case .transfer: return "Передача"
        case .debit: return "Списание"
        case .credit: return "Зачисление"
        }
    }
}

extension KWGramLocalOperationKind: Codable {
    private enum CodingKeys: String, CodingKey {
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .value)
        self = KWGramLocalOperationKind(rawValue: rawValue) ?? .topUp
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .value)
    }
}

/// One row in KW Gram's entirely local ledger. `amount` uses the smallest exact unit of
/// the selected currency: Stars = whole stars, TON = nanotons, RUB = kopecks.
public struct KWGramLocalOperation: Codable, Equatable, Identifiable {
    public let id: Int64
    public let currency: KWGramLocalCurrency
    public let kind: KWGramLocalOperationKind
    public let amount: Int64
    public let date: Int32
    public let title: String
    public let details: String
    public let peerId: PeerId?
    public let giftId: Int64?
    public let balanceAfter: Int64?

    public init(id: Int64 = Int64.random(in: 1 ... (Int64.max / 4)), currency: KWGramLocalCurrency, kind: KWGramLocalOperationKind, amount: Int64, date: Int32 = Int32(Date().timeIntervalSince1970), title: String, details: String = "", peerId: PeerId? = nil, giftId: Int64? = nil, balanceAfter: Int64? = nil) {
        self.id = id
        self.currency = currency
        self.kind = kind
        self.amount = amount
        self.date = date
        self.title = title
        self.details = details
        self.peerId = peerId
        self.giftId = giftId
        self.balanceAfter = balanceAfter
    }
}

private struct KWGramLocalOperationList: Codable {
    var items: [KWGramLocalOperation]
}

public struct KWGramLedgerStatistics: Equatable {
    public var incoming: Int64 = 0
    public var outgoing: Int64 = 0
    public var purchases: Int = 0
    public var sales: Int = 0
    public var topUps: Int = 0
    public var transfers: Int = 0
    public var operationCount: Int = 0

    public var net: Int64 { self.incoming - self.outgoing }
}

public enum KWGramLocalLedgerStore {
    public static func all(transaction: Transaction) -> [KWGramLocalOperation] {
        return transaction.getPreferencesEntry(key: KWGramPreferencesKeys.localOperations)?.get(KWGramLocalOperationList.self)?.items ?? []
    }

    public static func add(transaction: Transaction, operation: KWGramLocalOperation) {
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.localOperations, { entry in
            var list = entry?.get(KWGramLocalOperationList.self) ?? KWGramLocalOperationList(items: [])
            list.items.append(operation)
            if list.items.count > 5000 {
                list.items.removeFirst(list.items.count - 5000)
            }
            return PreferencesEntry(list)
        })
    }

    public static func remove(transaction: Transaction, id: Int64) {
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.localOperations, { entry in
            var list = entry?.get(KWGramLocalOperationList.self) ?? KWGramLocalOperationList(items: [])
            list.items.removeAll(where: { $0.id == id })
            return PreferencesEntry(list)
        })
    }

    public static func clear(transaction: Transaction) {
        transaction.setPreferencesEntry(key: KWGramPreferencesKeys.localOperations, value: PreferencesEntry(KWGramLocalOperationList(items: [])))
    }

    public static func signal(postbox: Postbox) -> Signal<[KWGramLocalOperation], NoError> {
        return postbox.preferencesView(keys: [KWGramPreferencesKeys.localOperations])
        |> map { view in
            let items = view.values[KWGramPreferencesKeys.localOperations]?.get(KWGramLocalOperationList.self)?.items ?? []
            return items.sorted(by: { $0.date > $1.date })
        }
    }

    /// Adds an operation and applies its amount to the matching local balance in one Postbox
    /// transaction. Positive amounts credit, negative amounts debit. The operation receives
    /// the exact balance-after value so the history remains useful even after later edits.
    public static func addAndApply(transaction: Transaction, currency: KWGramLocalCurrency, kind: KWGramLocalOperationKind, amount: Int64, title: String, details: String = "", peerId: PeerId? = nil, giftId: Int64? = nil) {
        var balanceAfter: Int64 = 0
        KWGramCore.updateSettings(transaction: transaction, { settings in
            var settings = settings
            switch currency {
            case .stars:
                settings.fakeStarsBalance += amount
                balanceAfter = settings.fakeStarsBalance
            case .ton:
                settings.fakeTonBalanceNanos += amount
                balanceAfter = settings.fakeTonBalanceNanos
            case .rubles:
                settings.localRublesBalanceKopecks += amount
                balanceAfter = settings.localRublesBalanceKopecks
            }
            return settings
        })
        self.add(transaction: transaction, operation: KWGramLocalOperation(currency: currency, kind: kind, amount: amount, title: title, details: details, peerId: peerId, giftId: giftId, balanceAfter: balanceAfter))
    }

    public static func currentBalance(transaction: Transaction, currency: KWGramLocalCurrency) -> Int64 {
        let settings = KWGramCore.settings(transaction: transaction)
        switch currency {
        case .stars: return settings.fakeStarsBalance
        case .ton: return settings.fakeTonBalanceNanos
        case .rubles: return settings.localRublesBalanceKopecks
        }
    }

    public static func statistics(_ operations: [KWGramLocalOperation], currency: KWGramLocalCurrency) -> KWGramLedgerStatistics {
        var result = KWGramLedgerStatistics()
        for operation in operations where operation.currency == currency {
            result.operationCount += 1
            if operation.amount >= 0 {
                result.incoming += operation.amount
            } else {
                result.outgoing += -operation.amount
            }
            switch operation.kind {
            case .purchase: result.purchases += 1
            case .sale: result.sales += 1
            case .topUp: result.topUps += 1
            case .transfer: result.transfers += 1
            case .debit, .credit: break
            }
        }
        return result
    }
}

public struct KWGramProfileVisualState: Codable, Equatable {
    public var ratingEnabled: Bool
    public var ratingValue: Int64
    public var ratingPoints: Int64
    public var anonymousNumberEnabled: Bool
    public var anonymousNumber: String
    public var anonymousNumberPurchasedAt: Int32
    public var anonymousNumberPriceTonNanos: Int64
    public var anonymousNumberPriceUsdCents: Int64

    public static var `default`: KWGramProfileVisualState {
        return KWGramProfileVisualState(
            ratingEnabled: false,
            ratingValue: 0,
            ratingPoints: 0,
            anonymousNumberEnabled: false,
            anonymousNumber: "+888 0000 0000",
            anonymousNumberPurchasedAt: Int32(Date().timeIntervalSince1970),
            anonymousNumberPriceTonNanos: 0,
            anonymousNumberPriceUsdCents: 0
        )
    }

    public init(ratingEnabled: Bool, ratingValue: Int64, ratingPoints: Int64, anonymousNumberEnabled: Bool, anonymousNumber: String, anonymousNumberPurchasedAt: Int32, anonymousNumberPriceTonNanos: Int64, anonymousNumberPriceUsdCents: Int64) {
        self.ratingEnabled = ratingEnabled
        self.ratingValue = ratingValue
        self.ratingPoints = ratingPoints
        self.anonymousNumberEnabled = anonymousNumberEnabled
        self.anonymousNumber = anonymousNumber
        self.anonymousNumberPurchasedAt = anonymousNumberPurchasedAt
        self.anonymousNumberPriceTonNanos = anonymousNumberPriceTonNanos
        self.anonymousNumberPriceUsdCents = anonymousNumberPriceUsdCents
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = KWGramProfileVisualState.default
        self.ratingEnabled = try container.decodeIfPresent(Bool.self, forKey: .ratingEnabled) ?? defaults.ratingEnabled
        self.ratingValue = try container.decodeIfPresent(Int64.self, forKey: .ratingValue) ?? defaults.ratingValue
        self.ratingPoints = try container.decodeIfPresent(Int64.self, forKey: .ratingPoints) ?? defaults.ratingPoints
        self.anonymousNumberEnabled = try container.decodeIfPresent(Bool.self, forKey: .anonymousNumberEnabled) ?? defaults.anonymousNumberEnabled
        self.anonymousNumber = try container.decodeIfPresent(String.self, forKey: .anonymousNumber) ?? defaults.anonymousNumber
        self.anonymousNumberPurchasedAt = try container.decodeIfPresent(Int32.self, forKey: .anonymousNumberPurchasedAt) ?? defaults.anonymousNumberPurchasedAt
        self.anonymousNumberPriceTonNanos = try container.decodeIfPresent(Int64.self, forKey: .anonymousNumberPriceTonNanos) ?? defaults.anonymousNumberPriceTonNanos
        self.anonymousNumberPriceUsdCents = try container.decodeIfPresent(Int64.self, forKey: .anonymousNumberPriceUsdCents) ?? defaults.anonymousNumberPriceUsdCents
    }
}

public enum KWGramProfileVisualStore {
    public static func state(transaction: Transaction) -> KWGramProfileVisualState {
        return transaction.getPreferencesEntry(key: KWGramPreferencesKeys.profileVisuals)?.get(KWGramProfileVisualState.self) ?? .default
    }

    public static func update(transaction: Transaction, _ f: (KWGramProfileVisualState) -> KWGramProfileVisualState) {
        transaction.setPreferencesEntry(key: KWGramPreferencesKeys.profileVisuals, value: PreferencesEntry(f(self.state(transaction: transaction))))
    }

    public static func signal(postbox: Postbox) -> Signal<KWGramProfileVisualState, NoError> {
        return postbox.preferencesView(keys: [KWGramPreferencesKeys.profileVisuals])
        |> map { view in
            view.values[KWGramPreferencesKeys.profileVisuals]?.get(KWGramProfileVisualState.self) ?? .default
        }
        |> distinctUntilChanged
    }
}

public enum KWGramAppearancePreset: String, CaseIterable {
    case standard
    case glass
    case compact

    public var displayName: String {
        switch self {
        case .standard: return "Стандартный"
        case .glass: return "Glass"
        case .compact: return "Compact"
        }
    }
}

extension KWGramAppearancePreset: Codable {
    private enum CodingKeys: String, CodingKey {
        case value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .value)
        self = KWGramAppearancePreset(rawValue: rawValue) ?? .standard
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.rawValue, forKey: .value)
    }
}

public struct KWGramAppearanceState: Codable, Equatable {
    public var preset: KWGramAppearancePreset
    public var bubbleRadius: Int32
    public var bubbleOpacityPercent: Int32
    public var chatDensity: Int32
    public var blurStrength: Int32
    public var animationsMode: Int32
    public var reduceAnimations: Bool
    public var oledBlack: Bool
    public var compactHub: Bool
    public var monochromeIcons: Bool
    public var showChatPreview: Bool
    public var showChatDate: Bool
    public var avatarSize: Int32
    public var profileHeaderBlur: Int32
    public var incomingColorHex: String
    public var outgoingColorHex: String
    public var inputRadius: Int32
    public var cardScalePercent: Int32
    public var iconScalePercent: Int32
    public var textScalePercent: Int32
    public var boldHeaders: Bool
    public var glassCards: Bool
    public var minimalMode: Bool
    public var avatarShape: Int32
    public var profileGradientHex: String
    // KW Gram "MonoColor UI": repaint avatars, story rings, name colours, folder tags and
    // profile colours in one single tone (`monoColorHex`, "#RRGGBB") while enabled.
    public var monoColorEnabled: Bool
    public var monoColorHex: String

    public static var `default`: KWGramAppearanceState {
        return KWGramAppearanceState(preset: .standard, bubbleRadius: 16, bubbleOpacityPercent: 100, chatDensity: 1, blurStrength: 40, animationsMode: 1, reduceAnimations: false, oledBlack: false, compactHub: false, monochromeIcons: false, showChatPreview: true, showChatDate: true, avatarSize: 48, profileHeaderBlur: 30, incomingColorHex: "#FFFFFF", outgoingColorHex: "#DCF8C6", inputRadius: 22, cardScalePercent: 100, iconScalePercent: 100, textScalePercent: 100, boldHeaders: true, glassCards: false, minimalMode: false, avatarShape: 0, profileGradientHex: "#2AABEE,#8774E1", monoColorEnabled: false, monoColorHex: "#4FAEDE")
    }

    public init(preset: KWGramAppearancePreset, bubbleRadius: Int32, bubbleOpacityPercent: Int32, chatDensity: Int32, blurStrength: Int32, animationsMode: Int32, reduceAnimations: Bool, oledBlack: Bool, compactHub: Bool, monochromeIcons: Bool, showChatPreview: Bool, showChatDate: Bool, avatarSize: Int32, profileHeaderBlur: Int32, incomingColorHex: String, outgoingColorHex: String, inputRadius: Int32, cardScalePercent: Int32, iconScalePercent: Int32, textScalePercent: Int32, boldHeaders: Bool, glassCards: Bool, minimalMode: Bool, avatarShape: Int32, profileGradientHex: String, monoColorEnabled: Bool, monoColorHex: String) {
        self.preset = preset
        self.bubbleRadius = bubbleRadius
        self.bubbleOpacityPercent = bubbleOpacityPercent
        self.chatDensity = chatDensity
        self.blurStrength = blurStrength
        self.animationsMode = animationsMode
        self.reduceAnimations = reduceAnimations
        self.oledBlack = oledBlack
        self.compactHub = compactHub
        self.monochromeIcons = monochromeIcons
        self.showChatPreview = showChatPreview
        self.showChatDate = showChatDate
        self.avatarSize = avatarSize
        self.profileHeaderBlur = profileHeaderBlur
        self.incomingColorHex = incomingColorHex
        self.outgoingColorHex = outgoingColorHex
        self.inputRadius = inputRadius
        self.cardScalePercent = cardScalePercent
        self.iconScalePercent = iconScalePercent
        self.textScalePercent = textScalePercent
        self.boldHeaders = boldHeaders
        self.glassCards = glassCards
        self.minimalMode = minimalMode
        self.avatarShape = avatarShape
        self.profileGradientHex = profileGradientHex
        self.monoColorEnabled = monoColorEnabled
        self.monoColorHex = monoColorHex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KWGramAppearanceState.default
        self.preset = try c.decodeIfPresent(KWGramAppearancePreset.self, forKey: .preset) ?? d.preset
        self.bubbleRadius = try c.decodeIfPresent(Int32.self, forKey: .bubbleRadius) ?? d.bubbleRadius
        self.bubbleOpacityPercent = try c.decodeIfPresent(Int32.self, forKey: .bubbleOpacityPercent) ?? d.bubbleOpacityPercent
        self.chatDensity = try c.decodeIfPresent(Int32.self, forKey: .chatDensity) ?? d.chatDensity
        self.blurStrength = try c.decodeIfPresent(Int32.self, forKey: .blurStrength) ?? d.blurStrength
        self.animationsMode = try c.decodeIfPresent(Int32.self, forKey: .animationsMode) ?? d.animationsMode
        self.reduceAnimations = try c.decodeIfPresent(Bool.self, forKey: .reduceAnimations) ?? d.reduceAnimations
        self.oledBlack = try c.decodeIfPresent(Bool.self, forKey: .oledBlack) ?? d.oledBlack
        self.compactHub = try c.decodeIfPresent(Bool.self, forKey: .compactHub) ?? d.compactHub
        self.monochromeIcons = try c.decodeIfPresent(Bool.self, forKey: .monochromeIcons) ?? d.monochromeIcons
        self.showChatPreview = try c.decodeIfPresent(Bool.self, forKey: .showChatPreview) ?? d.showChatPreview
        self.showChatDate = try c.decodeIfPresent(Bool.self, forKey: .showChatDate) ?? d.showChatDate
        self.avatarSize = try c.decodeIfPresent(Int32.self, forKey: .avatarSize) ?? d.avatarSize
        self.profileHeaderBlur = try c.decodeIfPresent(Int32.self, forKey: .profileHeaderBlur) ?? d.profileHeaderBlur
        self.incomingColorHex = try c.decodeIfPresent(String.self, forKey: .incomingColorHex) ?? d.incomingColorHex
        self.outgoingColorHex = try c.decodeIfPresent(String.self, forKey: .outgoingColorHex) ?? d.outgoingColorHex
        self.inputRadius = try c.decodeIfPresent(Int32.self, forKey: .inputRadius) ?? d.inputRadius
        self.cardScalePercent = try c.decodeIfPresent(Int32.self, forKey: .cardScalePercent) ?? d.cardScalePercent
        self.iconScalePercent = try c.decodeIfPresent(Int32.self, forKey: .iconScalePercent) ?? d.iconScalePercent
        self.textScalePercent = try c.decodeIfPresent(Int32.self, forKey: .textScalePercent) ?? d.textScalePercent
        self.boldHeaders = try c.decodeIfPresent(Bool.self, forKey: .boldHeaders) ?? d.boldHeaders
        self.glassCards = try c.decodeIfPresent(Bool.self, forKey: .glassCards) ?? d.glassCards
        self.minimalMode = try c.decodeIfPresent(Bool.self, forKey: .minimalMode) ?? d.minimalMode
        self.avatarShape = try c.decodeIfPresent(Int32.self, forKey: .avatarShape) ?? d.avatarShape
        self.profileGradientHex = try c.decodeIfPresent(String.self, forKey: .profileGradientHex) ?? d.profileGradientHex
        self.monoColorEnabled = try c.decodeIfPresent(Bool.self, forKey: .monoColorEnabled) ?? d.monoColorEnabled
        self.monoColorHex = try c.decodeIfPresent(String.self, forKey: .monoColorHex) ?? d.monoColorHex
    }
}

public enum KWGramAppearanceStore {
    public static func state(transaction: Transaction) -> KWGramAppearanceState {
        return transaction.getPreferencesEntry(key: KWGramPreferencesKeys.appearance)?.get(KWGramAppearanceState.self) ?? .default
    }
    public static func update(transaction: Transaction, _ f: (KWGramAppearanceState) -> KWGramAppearanceState) {
        transaction.setPreferencesEntry(key: KWGramPreferencesKeys.appearance, value: PreferencesEntry(f(self.state(transaction: transaction))))
    }
    public static func signal(postbox: Postbox) -> Signal<KWGramAppearanceState, NoError> {
        return postbox.preferencesView(keys: [KWGramPreferencesKeys.appearance])
        |> map { $0.values[KWGramPreferencesKeys.appearance]?.get(KWGramAppearanceState.self) ?? .default }
        |> distinctUntilChanged
    }
}

public struct KWGramBehaviorState: Codable, Equatable {
    public var showProfileIds: Bool
    public var hideOwnPhone: Bool
    public var translationEnabled: Bool
    public var translationTargetLanguage: String

    public static var `default`: KWGramBehaviorState {
        return KWGramBehaviorState(showProfileIds: true, hideOwnPhone: false, translationEnabled: true, translationTargetLanguage: "ru")
    }

    public init(showProfileIds: Bool, hideOwnPhone: Bool, translationEnabled: Bool, translationTargetLanguage: String) {
        self.showProfileIds = showProfileIds
        self.hideOwnPhone = hideOwnPhone
        self.translationEnabled = translationEnabled
        self.translationTargetLanguage = translationTargetLanguage
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KWGramBehaviorState.default
        self.showProfileIds = try c.decodeIfPresent(Bool.self, forKey: .showProfileIds) ?? d.showProfileIds
        self.hideOwnPhone = try c.decodeIfPresent(Bool.self, forKey: .hideOwnPhone) ?? d.hideOwnPhone
        self.translationEnabled = try c.decodeIfPresent(Bool.self, forKey: .translationEnabled) ?? d.translationEnabled
        self.translationTargetLanguage = try c.decodeIfPresent(String.self, forKey: .translationTargetLanguage) ?? d.translationTargetLanguage
    }
}

public enum KWGramBehaviorStore {
    public static func state(transaction: Transaction) -> KWGramBehaviorState {
        return transaction.getPreferencesEntry(key: KWGramPreferencesKeys.behavior)?.get(KWGramBehaviorState.self) ?? .default
    }
    public static func update(transaction: Transaction, _ f: (KWGramBehaviorState) -> KWGramBehaviorState) {
        transaction.setPreferencesEntry(key: KWGramPreferencesKeys.behavior, value: PreferencesEntry(f(self.state(transaction: transaction))))
    }
    public static func signal(postbox: Postbox) -> Signal<KWGramBehaviorState, NoError> {
        return postbox.preferencesView(keys: [KWGramPreferencesKeys.behavior])
        |> map { $0.values[KWGramPreferencesKeys.behavior]?.get(KWGramBehaviorState.self) ?? .default }
        |> distinctUntilChanged
    }
}

public struct KWGramFakeAdminChannelState: Codable, Equatable {
    public var peerId: PeerId
    public var enabled: Bool
    public var titleOverride: String?
    public var descriptionOverride: String?
    public var reactionsEnabled: Bool?
    public var inviteLinkOverride: String?

    public init(peerId: PeerId, enabled: Bool, titleOverride: String? = nil, descriptionOverride: String? = nil, reactionsEnabled: Bool? = nil, inviteLinkOverride: String? = nil) {
        self.peerId = peerId
        self.enabled = enabled
        self.titleOverride = titleOverride
        self.descriptionOverride = descriptionOverride
        self.reactionsEnabled = reactionsEnabled
        self.inviteLinkOverride = inviteLinkOverride
    }
}

private struct KWGramFakeAdminList: Codable {
    var channels: [KWGramFakeAdminChannelState]
}

public enum KWGramFakeAdminStore {
    public static func all(transaction: Transaction) -> [KWGramFakeAdminChannelState] {
        return transaction.getPreferencesEntry(key: KWGramPreferencesKeys.fakeAdmin)?.get(KWGramFakeAdminList.self)?.channels ?? []
    }
    public static func state(transaction: Transaction, peerId: PeerId) -> KWGramFakeAdminChannelState? {
        return self.all(transaction: transaction).first(where: { $0.peerId == peerId })
    }
    public static func isEnabled(transaction: Transaction, peerId: PeerId) -> Bool {
        return self.state(transaction: transaction, peerId: peerId)?.enabled == true
    }
    public static func update(transaction: Transaction, peerId: PeerId, _ f: (KWGramFakeAdminChannelState) -> KWGramFakeAdminChannelState) {
        transaction.updatePreferencesEntry(key: KWGramPreferencesKeys.fakeAdmin, { entry in
            var list = entry?.get(KWGramFakeAdminList.self) ?? KWGramFakeAdminList(channels: [])
            let base = list.channels.first(where: { $0.peerId == peerId }) ?? KWGramFakeAdminChannelState(peerId: peerId, enabled: false)
            let value = f(base)
            list.channels.removeAll(where: { $0.peerId == peerId })
            list.channels.append(value)
            return PreferencesEntry(list)
        })
    }
    public static func signal(postbox: Postbox, peerId: PeerId) -> Signal<KWGramFakeAdminChannelState, NoError> {
        return postbox.preferencesView(keys: [KWGramPreferencesKeys.fakeAdmin])
        |> map { view in
            let list = view.values[KWGramPreferencesKeys.fakeAdmin]?.get(KWGramFakeAdminList.self)?.channels ?? []
            return list.first(where: { $0.peerId == peerId }) ?? KWGramFakeAdminChannelState(peerId: peerId, enabled: false)
        }
        |> distinctUntilChanged
    }

    /// Live list of every channel with a fake-admin record (enabled or not), for the
    /// "Фейк админ" management screen.
    public static func allSignal(postbox: Postbox) -> Signal<[KWGramFakeAdminChannelState], NoError> {
        return postbox.preferencesView(keys: [KWGramPreferencesKeys.fakeAdmin])
        |> map { view in
            return view.values[KWGramPreferencesKeys.fakeAdmin]?.get(KWGramFakeAdminList.self)?.channels ?? []
        }
        |> distinctUntilChanged
    }
}
