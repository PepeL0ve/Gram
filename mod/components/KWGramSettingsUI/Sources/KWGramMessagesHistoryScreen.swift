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
import KWGramCore

private final class KWGramMessagesHistoryArguments {
    let openChat: (PeerId) -> Void

    init(openChat: @escaping (PeerId) -> Void) {
        self.openChat = openChat
    }
}

private enum KWGramMessagesHistoryEntry: ItemListNodeEntry {
    case empty
    case message(KWGramDeletedMessage, String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int64 {
        switch self {
        case .empty:
            return 0
        case let .message(message, _):
            return message.id
        }
    }

    static func ==(lhs: KWGramMessagesHistoryEntry, rhs: KWGramMessagesHistoryEntry) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty):
            return true
        case let (.message(lhsMessage, lhsTitle), .message(rhsMessage, rhsTitle)):
            return lhsMessage == rhsMessage && lhsTitle == rhsTitle
        default:
            return false
        }
    }

    static func <(lhs: KWGramMessagesHistoryEntry, rhs: KWGramMessagesHistoryEntry) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty):
            return false
        case (.empty, .message):
            return true
        case (.message, .empty):
            return false
        case let (.message(lhsMessage, _), .message(rhsMessage, _)):
            return lhsMessage.deletedAt > rhsMessage.deletedAt
        }
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KWGramMessagesHistoryArguments
        switch self {
        case .empty:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Пока ничего не восстановлено."), sectionId: self.section)
        case let .message(message, peerTitle):
            let date = Date(timeIntervalSince1970: Double(message.deletedAt))
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            let preview = message.textPreview.isEmpty ? "Сообщение" : message.textPreview
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: peerTitle,
                titleFont: .bold,
                label: formatter.string(from: date),
                additionalDetailLabel: preview,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openChat(message.peerId)
                }
            )
        }
    }
}

/// Every message the anti-delete feature has captured on this device, newest first — reached
/// from the "Сообщения" section's "Восстановленные сообщения" row.
public func kwGramMessagesHistoryController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = KWGramMessagesHistoryArguments(
        openChat: { peerId in
            let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peerId), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
            pushControllerImpl?(chatController)
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        KWGramDeletedMessageStore.allSignal(postbox: context.account.postbox)
    )
    |> mapToSignal { presentationData, messages -> Signal<(PresentationData, [KWGramDeletedMessage], [PeerId: EnginePeer?]), NoError> in
        let peerIds = Set(messages.map { $0.peerId })
        return context.engine.data.subscribe(
            EngineDataMap(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init))
        )
        |> map { peers -> (PresentationData, [KWGramDeletedMessage], [PeerId: EnginePeer?]) in
            return (presentationData, messages, peers)
        }
    }
    |> deliverOnMainQueue
    |> map { presentationData, messages, peers -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Восстановленные сообщения"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let entries: [KWGramMessagesHistoryEntry]
        if messages.isEmpty {
            entries = [.empty]
        } else {
            entries = messages.map { message in
                let peerTitle = (peers[message.peerId] ?? nil)?.compactDisplayTitle ?? "Неизвестный чат"
                return .message(message, peerTitle)
            }
        }
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
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
