import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import AppBundle
import KWGramCore

private final class KWGramStatusArguments {
    let openIconPicker: () -> Void
    let openGifts: () -> Void
    let openMessages: () -> Void
    let openProfile: () -> Void
    let openGhost: () -> Void

    init(openIconPicker: @escaping () -> Void, openGifts: @escaping () -> Void, openMessages: @escaping () -> Void, openProfile: @escaping () -> Void, openGhost: @escaping () -> Void) {
        self.openIconPicker = openIconPicker
        self.openGifts = openGifts
        self.openMessages = openMessages
        self.openProfile = openProfile
        self.openGhost = openGhost
    }
}

/// Turns a raw alternate-icon codename (e.g. "BlueClassicIcon", "New2") into something
/// readable without inventing style descriptions we can't verify — just the real name with
/// word breaks inserted before each capital. Not private: KWGramIconPickerScreen.swift's
/// grid cells and confirm dialog use it too.
func kwGramIconDisplayName(_ icon: PresentationAppIcon) -> String {
    if icon.isDefault {
        return "Стандартная"
    }
    var name = icon.name
    if name.hasSuffix("Icon") {
        name.removeLast(4)
    }
    var result = ""
    for (index, character) in name.enumerated() {
        if index > 0 && character.isUppercase {
            result += " "
        }
        result.append(character)
    }
    return result.isEmpty ? icon.name : result
}

private enum KWGramStatusEntry: ItemListNodeEntry {
    case badge(Bool)

    case iconHeader(String)
    case iconSummary(PresentationAppIcon)
    case iconFooter(String)

    case giftsHeader(String)
    case giftsRow(Int32, String, Bool)

    case messagesHeader(String)
    case messagesRow(Int32, String, Bool)

    case profileHeader(String)
    case profileRow(Int32, String, Bool)

    case ghostHeader(String)
    case ghostRow(Int32, String, Bool)

    var section: ItemListSectionId {
        switch self {
        case .badge:
            return 0
        case .iconHeader, .iconSummary, .iconFooter:
            return 1
        case .giftsHeader, .giftsRow:
            return 2
        case .messagesHeader, .messagesRow:
            return 3
        case .profileHeader, .profileRow:
            return 4
        case .ghostHeader, .ghostRow:
            return 5
        }
    }

    var stableId: Int32 {
        switch self {
        case .badge:
            return 0
        case .iconHeader:
            return 1
        case .iconSummary:
            return 100
        case .iconFooter:
            return 199
        case .giftsHeader:
            return 200
        case let .giftsRow(index, _, _):
            return 201 + index
        case .messagesHeader:
            return 220
        case let .messagesRow(index, _, _):
            return 221 + index
        case .profileHeader:
            return 230
        case let .profileRow(index, _, _):
            return 231 + index
        case .ghostHeader:
            return 240
        case let .ghostRow(index, _, _):
            return 241 + index
        }
    }

    static func <(lhs: KWGramStatusEntry, rhs: KWGramStatusEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KWGramStatusArguments
        switch self {
        case let .badge(isPro):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: kwGramSettingsIcon(size: 44.0),
                title: "Статус",
                titleFont: .bold,
                titleBadge: isPro ? "PRO" : "STANDARD",
                label: "",
                additionalDetailLabel: "Выбери свой стиль приложения и подписку",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        case let .iconHeader(text), let .giftsHeader(text), let .messagesHeader(text), let .profileHeader(text), let .ghostHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .iconFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .iconSummary(icon):
            let previewImage = UIImage(named: icon.imageName, in: getAppBundle(), compatibleWith: nil).flatMap { generateKWGramIconPreview($0) }
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: previewImage,
                title: "Иконка приложения",
                label: kwGramIconDisplayName(icon),
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openIconPicker()
                }
            )
        case let .giftsRow(_, title, isOn):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "gift.fill", backgroundColor: UIColor(rgb: 0x8e44ec)),
                title: title,
                label: "",
                additionalDetailLabel: isOn ? "Включено" : "Выключено",
                additionalDetailLabelColor: isOn ? .constructive : .destructive,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openGifts()
                }
            )
        case let .messagesRow(_, title, isOn):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "message.fill", backgroundColor: UIColor(rgb: 0x3b82f6)),
                title: title,
                label: "",
                additionalDetailLabel: isOn ? "Включено" : "Выключено",
                additionalDetailLabelColor: isOn ? .constructive : .destructive,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openMessages()
                }
            )
        case let .profileRow(_, title, isOn):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "person.fill", backgroundColor: UIColor(rgb: 0x5856d6)),
                title: title,
                label: "",
                additionalDetailLabel: isOn ? "Включено" : "Выключено",
                additionalDetailLabelColor: isOn ? .constructive : .destructive,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openProfile()
                }
            )
        case let .ghostRow(_, title, isOn):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "eye.slash.fill", backgroundColor: UIColor(rgb: 0x34c759)),
                title: title,
                label: "",
                additionalDetailLabel: isOn ? "Включено" : "Выключено",
                additionalDetailLabelColor: isOn ? .constructive : .destructive,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openGhost()
                }
            )
        }
    }
}

private func kwGramStatusEntries(isPro: Bool, icons: [PresentationAppIcon], currentIconName: String?, settings: KWGramSettings, profileVisuals: KWGramProfileVisualState) -> [KWGramStatusEntry] {
    var entries: [KWGramStatusEntry] = []

    entries.append(.badge(isPro))

    entries.append(.iconHeader("ИКОНКА ПРИЛОЖЕНИЯ"))
    if let selectedIcon = icons.first(where: { $0.name == currentIconName }) ?? icons.first(where: { $0.isDefault }) ?? icons.first {
        entries.append(.iconSummary(selectedIcon))
    }
    entries.append(.iconFooter("Иконка меняется сразу на домашнем экране."))

    entries.append(.giftsHeader("ПОДАРКИ"))
    entries.append(.giftsRow(0, "Вкладка «Подарок ему»", settings.phantomGiftsEnabled))
    entries.append(.giftsRow(1, "Локальные звёзды", settings.fakeStarsDisplayEnabled))
    entries.append(.giftsRow(2, "Локальные TON/GRAM", settings.fakeTonDisplayEnabled))
    entries.append(.giftsRow(3, "От него", settings.fromHimGiftsEnabled))

    entries.append(.messagesHeader("ЧАТЫ"))
    entries.append(.messagesRow(0, "Удалённые сообщения", settings.antiDeleteMessagesEnabled))
    entries.append(.messagesRow(1, "Изменить визуально", settings.visualEditEnabled))

    entries.append(.profileHeader("ПРОФИЛЬ"))
    entries.append(.profileRow(0, "Визуальный +888", profileVisuals.anonymousNumberEnabled))
    entries.append(.profileRow(1, "Визуальный рейтинг", profileVisuals.ratingEnabled))
    entries.append(.profileRow(2, "Время в ник", settings.timeInNicknameEnabled))

    entries.append(.ghostHeader("GHOST"))
    entries.append(.ghostRow(0, "Режим призрака", settings.ghostModeEnabled))
    entries.append(.ghostRow(1, "Не читать сообщения", settings.ghostModeEnabled && settings.ghostHideReadReceipts))
    entries.append(.ghostRow(2, "Не читать истории", settings.ghostModeEnabled && settings.ghostHideStoryViews))
    entries.append(.ghostRow(3, "Не отправлять «онлайн»", settings.ghostModeEnabled && settings.ghostHideOnline))
    entries.append(.ghostRow(4, "Не отправлять «печатает»", settings.ghostModeEnabled && settings.ghostHideTyping))
    entries.append(.ghostRow(5, "Автоматический «офлайн»", settings.ghostModeEnabled && settings.ghostAutoOffline))
    entries.append(.ghostRow(6, "Читать при действиях", settings.ghostModeEnabled && settings.ghostReadOnAction))

    return entries
}

/// "Статус": KW Gram's own hub row for both this account's KW Gram subscription tier
/// (PRO/STANDARD — granted by the admin panel, see `KWGramSubscriptionAPI.swift`; this is
/// the one screen in the mod that reads from KW Gram's own server instead of only local
/// state) and the app-icon picker (wired to Telegram's own real
/// `applicationBindings.requestSetAlternateIconName`, so picking one genuinely changes the
/// home-screen icon), plus a grouped, tap-to-open read-out of every KW Gram toggle.
public func kwGramStatusController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var currentIconNameValue = context.sharedContext.applicationBindings.getAlternateIconName()
    let currentIconName = ValuePromise<String?>(currentIconNameValue)

    var appIcons = context.sharedContext.applicationBindings.getAvailableAlternateIcons()
    appIcons = appIcons.filter { !$0.isPremium }

    let arguments = KWGramStatusArguments(
        openIconPicker: {
            kwGramPresentIconPicker(context: context, icons: appIcons, currentIconName: currentIconNameValue, onSelect: { icon in
                currentIconNameValue = icon.name
                currentIconName.set(icon.name)
            })
        },
        openGifts: {
            kwGramGateSection(context: context, section: .gifts) {
                pushControllerImpl?(kwGramGiftsSettingsController(context: context))
            }
        },
        openMessages: {
            kwGramGateSection(context: context, section: .messages) {
                pushControllerImpl?(kwGramMessagesSettingsController(context: context))
            }
        },
        openProfile: {
            kwGramGateSection(context: context, section: .profile) {
                pushControllerImpl?(kwGramProfileSettingsController(context: context))
            }
        },
        openGhost: {
            kwGramGateSection(context: context, section: .ghost) {
                pushControllerImpl?(kwGramGhostSettingsController(context: context))
            }
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        KWGramCore.settingsSignal(postbox: context.account.postbox),
        KWGramProfileVisualStore.signal(postbox: context.account.postbox),
        KWGramSubscriptionAPI.fetchTier(userId: context.account.peerId.id._internalGetInt64Value()),
        currentIconName.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings, profileVisuals, subscriptionTier, currentIconName -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Статус"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let isPro = subscriptionTier == .pro
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: kwGramStatusEntries(isPro: isPro, icons: appIcons, currentIconName: currentIconName, settings: settings, profileVisuals: profileVisuals),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}
