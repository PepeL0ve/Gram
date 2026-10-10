import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import PromptUI
import UndoUI
import KWGramCore

private final class KWGramChatLockArguments {
    let toggleEnabled: (Bool) -> Void
    let editPin: () -> Void
    let openPeers: () -> Void

    init(toggleEnabled: @escaping (Bool) -> Void, editPin: @escaping () -> Void, openPeers: @escaping () -> Void) {
        self.toggleEnabled = toggleEnabled
        self.editPin = editPin
        self.openPeers = openPeers
    }
}

private enum KWGramChatLockSection: Int32 {
    case about
    case lock
}

private enum KWGramChatLockEntry: ItemListNodeEntry {
    case aboutText(String)

    case enabledToggle(String, Bool)
    case pinRow(String, String)
    case peersRow(String, String)
    case footer(String)

    var section: ItemListSectionId {
        switch self {
        case .aboutText:
            return KWGramChatLockSection.about.rawValue
        case .enabledToggle, .pinRow, .peersRow, .footer:
            return KWGramChatLockSection.lock.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .aboutText:
            return 0
        case .enabledToggle:
            return 1
        case .pinRow:
            return 2
        case .peersRow:
            return 3
        case .footer:
            return 4
        }
    }

    static func <(lhs: KWGramChatLockEntry, rhs: KWGramChatLockEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KWGramChatLockArguments
        switch self {
        case let .aboutText(text), let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .enabledToggle(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleEnabled(value)
            })
        case let .pinRow(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.editPin()
            })
        case let .peersRow(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openPeers()
            })
        }
    }
}

private func kwGramChatLockEntries(settings: KWGramSettings) -> [KWGramChatLockEntry] {
    var entries: [KWGramChatLockEntry] = []

    entries.append(.aboutText("Требует PIN-код перед открытием выбранных чатов — только на этом устройстве."))

    entries.append(.enabledToggle("Блокировка чатов", settings.chatLockEnabled))
    entries.append(.pinRow("PIN-код", settings.chatLockPin.isEmpty ? "Не задан" : String(repeating: "•", count: settings.chatLockPin.count)))
    entries.append(.peersRow("Защищённые чаты", "\(settings.lockedChatPeerIds.count)"))
    entries.append(.footer("Не заменяет пароль приложения или секретные чаты Telegram — если забудешь PIN, сбросить его можно только через это же меню."))

    return entries
}

/// "Блокировка чатов" (Дополнительно): a single local PIN gating open access to specific
/// chats, checked once before real navigation in `navigateToChatControllerImpl` — see the
/// patch to `NavigateToChatController.swift`.
public func kwGramChatLockController(context: AccountContext) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentTooltipImpl: ((String) -> Void)?

    let arguments = KWGramChatLockArguments(
        toggleEnabled: { value in
            let _ = KWGramCore.updateSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.chatLockEnabled = value
                return settings
            }).start()
        },
        editPin: {
            presentControllerImpl?(promptController(
                context: context,
                text: "PIN-код",
                subtitle: "Только цифры, от 4 до 8 символов.",
                value: "",
                placeholder: "0000",
                characterLimit: 8,
                apply: { value in
                    guard let value = value, !value.isEmpty else {
                        return
                    }
                    let digitsOnly = value.filter { $0.isNumber }
                    guard digitsOnly.count >= 4 && digitsOnly.count <= 8 else {
                        presentTooltipImpl?("PIN-код должен быть от 4 до 8 цифр.")
                        return
                    }
                    let _ = KWGramCore.updateSettingsInteractively(postbox: context.account.postbox, { settings in
                        var settings = settings
                        settings.chatLockPin = digitsOnly
                        return settings
                    }).start()
                }
            ))
        },
        openPeers: {
            pushControllerImpl?(kwGramChatLockPeersController(context: context))
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        KWGramCore.settingsSignal(postbox: context.account.postbox)
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Блокировка чатов"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: kwGramChatLockEntries(settings: settings),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    presentTooltipImpl = { [weak controller] text in
        guard let controller else {
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        controller.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: text, timeout: nil, customUndoText: nil), elevatedLayout: false, action: { _ in return false }), in: .current)
    }
    return controller
}
