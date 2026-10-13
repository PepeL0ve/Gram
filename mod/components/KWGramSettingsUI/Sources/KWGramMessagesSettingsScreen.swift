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
import UndoUI
import KWGramCore

private final class KWGramMessagesArguments {
    let toggleAntiDelete: (Bool) -> Void
    let openExclusions: () -> Void
    let toggleVisualEdit: (Bool) -> Void
    let openHistory: () -> Void
    let clearHistory: () -> Void
    let exportChat: () -> Void
    let toggleGiftSearch: (Bool) -> Void

    init(toggleAntiDelete: @escaping (Bool) -> Void, openExclusions: @escaping () -> Void, toggleVisualEdit: @escaping (Bool) -> Void, openHistory: @escaping () -> Void, clearHistory: @escaping () -> Void, exportChat: @escaping () -> Void, toggleGiftSearch: @escaping (Bool) -> Void) {
        self.toggleAntiDelete = toggleAntiDelete
        self.openExclusions = openExclusions
        self.toggleVisualEdit = toggleVisualEdit
        self.openHistory = openHistory
        self.clearHistory = clearHistory
        self.exportChat = exportChat
        self.toggleGiftSearch = toggleGiftSearch
    }
}

private enum KWGramMessagesSection: Int32 {
    case about
    case antiDelete
    case visualEdit
    case history
    case export
    case search
}

private enum KWGramMessagesEntry: ItemListNodeEntry {
    case aboutText(String)

    case antiDeleteToggle(String, Bool)
    case exclusionsRow(String, String)
    case antiDeleteFooter(String)

    case visualEditToggle(String, Bool)
    case visualEditFooter(String)

    case historyHeader(String)
    case historyList(String, String)
    case clearHistory(String, Bool)
    case historyFooter(String)

    case exportHeader(String)
    case exportChat(String)
    case exportFooter(String)

    case searchHeader(String)
    case searchToggle(String, Bool)
    case searchFooter(String)

    var section: ItemListSectionId {
        switch self {
        case .aboutText:
            return KWGramMessagesSection.about.rawValue
        case .antiDeleteToggle, .exclusionsRow, .antiDeleteFooter:
            return KWGramMessagesSection.antiDelete.rawValue
        case .visualEditToggle, .visualEditFooter:
            return KWGramMessagesSection.visualEdit.rawValue
        case .historyHeader, .historyList, .clearHistory, .historyFooter:
            return KWGramMessagesSection.history.rawValue
        case .exportHeader, .exportChat, .exportFooter:
            return KWGramMessagesSection.export.rawValue
        case .searchHeader, .searchToggle, .searchFooter:
            return KWGramMessagesSection.search.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .aboutText:
            return 0
        case .antiDeleteToggle:
            return 1
        case .exclusionsRow:
            return 2
        case .antiDeleteFooter:
            return 3
        case .visualEditToggle:
            return 4
        case .visualEditFooter:
            return 5
        case .historyHeader:
            return 6
        case .historyList:
            return 7
        case .clearHistory:
            return 8
        case .historyFooter:
            return 9
        case .exportHeader:
            return 10
        case .exportChat:
            return 11
        case .exportFooter:
            return 12
        case .searchHeader:
            return 13
        case .searchToggle:
            return 14
        case .searchFooter:
            return 15
        }
    }

    static func <(lhs: KWGramMessagesEntry, rhs: KWGramMessagesEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KWGramMessagesArguments
        switch self {
        case let .aboutText(text), let .antiDeleteFooter(text), let .visualEditFooter(text), let .historyFooter(text), let .exportFooter(text), let .searchFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .historyHeader(text), let .exportHeader(text), let .searchHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .antiDeleteToggle(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: "Сообщения, удалённые собеседником, остаются видимыми у вас.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleAntiDelete(value)
            })
        case let .exclusionsRow(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openExclusions()
            })
        case let .visualEditToggle(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: "Изменяет текст чужого сообщения только на вашем устройстве.", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleVisualEdit(value)
            })
        case let .historyList(title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openHistory()
            })
        case let .clearHistory(title, enabled):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: enabled ? .destructive : .disabled, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                arguments.clearHistory()
            })
        case let .exportChat(title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.exportChat()
            })
        case let .searchToggle(title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: "Поиск подарков в один клик — добавляет отдельную вкладку «Подарки» прямо в глобальный поиск Telegram", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleGiftSearch(value)
            })
        }
    }
}

private func kwGramMessagesEntries(settings: KWGramSettings, historyCount: Int) -> [KWGramMessagesEntry] {
    var entries: [KWGramMessagesEntry] = []

    entries.append(.aboutText("Работает только на этом устройстве, никому не сообщается."))

    entries.append(.antiDeleteToggle("Удалённые сообщения", settings.antiDeleteMessagesEnabled))
    entries.append(.exclusionsRow("Исключения", "\(settings.antiDeleteExcludedPeerIds.count)"))
    entries.append(.antiDeleteFooter("Удалённое собеседником сообщение остаётся в чате затемнённым, с иконкой корзины. В исключённых чатах — как обычно."))

    entries.append(.visualEditToggle("Изменить визуально", settings.visualEditEnabled))
    entries.append(.visualEditFooter("Добавляет в меню сообщения собеседника (зажать → KW Gram) кнопку «Изменить визуально» — меняет текст только у вас."))

    entries.append(.historyHeader("ИСТОРИЯ"))
    entries.append(.historyList("Восстановленные сообщения", "\(historyCount)"))
    entries.append(.clearHistory("Очистить всю историю", historyCount > 0))
    entries.append(.historyFooter("Уберёт восстановленные сообщения из чатов. Отменить нельзя."))

    entries.append(.exportHeader("ЭКСПОРТ"))
    entries.append(.exportChat("Экспорт чата в .txt"))
    entries.append(.exportFooter("Выбери чат — сохраню его историю в .txt и отправлю файл в Избранное."))

    entries.append(.searchHeader("ПОИСК"))
    entries.append(.searchToggle("Поиск подарков", settings.giftSearchTab))
    entries.append(.searchFooter("Откройте вкладку «Подарки» в глобальном поиске и введите имя коллекции"))

    return entries
}

/// The "Чаты" section (hub row title — the screen itself still deals with anti-delete
/// messages specifically): the anti-delete feature's master toggle, its per-chat exclusion
/// list, and a link into its capture history.
public func kwGramMessagesSettingsController(context: AccountContext) -> ViewController {
    var presentTooltipImpl: ((String) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = KWGramMessagesArguments(
        toggleAntiDelete: { value in
            let _ = KWGramCore.updateSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.antiDeleteMessagesEnabled = value
                return settings
            }).start()
        },
        openExclusions: {
            pushControllerImpl?(kwGramMessagesExclusionsController(context: context))
        },
        toggleVisualEdit: { value in
            let _ = KWGramCore.updateSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.visualEditEnabled = value
                return settings
            }).start()
        },
        openHistory: {
            pushControllerImpl?(kwGramMessagesHistoryController(context: context))
        },
        clearHistory: {
            let _ = (context.account.postbox.transaction { transaction -> Void in
                let removed = KWGramDeletedMessageStore.removeAll(transaction: transaction)
                transaction.deleteMessages(removed.map { $0.localMessageId }, forEachMedia: { _ in })
            }
            |> deliverOnMainQueue).start(completed: {
                presentTooltipImpl?("История очищена.")
            })
        },
        exportChat: {
            guard let presentTooltipImpl, let presentControllerImpl else {
                return
            }
            kwGramExportChatAction(
                context: context,
                presentController: { c in
                    presentControllerImpl(c)
                },
                presentTooltip: { text in
                    presentTooltipImpl(text)
                }
            )
        },
        toggleGiftSearch: { value in
            let _ = KWGramCore.updateSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.giftSearchTab = value
                return settings
            }).start()
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        KWGramCore.settingsSignal(postbox: context.account.postbox),
        KWGramDeletedMessageStore.allSignal(postbox: context.account.postbox)
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings, history -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Чаты"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: kwGramMessagesEntries(settings: settings, historyCount: history.count),
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
