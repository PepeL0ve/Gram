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

/// Builds one plain-text export line: `[N Name] [HH:MM DD.MM.YYYY] - Message`. `N` is a
/// 1-based sequence number across the whole export; media-only messages get a placeholder so
/// the chronology stays intact.
private func kwGramExportLine(index: Int, name: String, timestamp: Int32, text: String) -> String {
    let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU_POSIX")
    formatter.dateFormat = "HH:mm dd.MM.yyyy"
    let stamp = formatter.string(from: date)
    let body = text.isEmpty ? "[вложение]" : text.replacingOccurrences(of: "\n", with: " ")
    return "[\(index) \(name)] [\(stamp)] - \(body)"
}

/// Loads a peer's full cloud history, oldest → newest. Pages backwards from the newest message
/// through `aroundMessageHistoryViewForLocation` (first page) then `aroundIdMessageHistoryViewForLocation`
/// (each earlier page, anchored on the previous page's oldest message) until `holeEarlier` is
/// false. De-duplicates by message id because pages can overlap at the seams.
private func kwGramLoadAllMessages(context: AccountContext, peerId: PeerId, threadId: Int64?) -> Signal<[Message], NoError> {
    let pageSize = 500
    let location = ChatLocationInput.peer(peerId: peerId, threadId: threadId)

    return Signal { subscriber in
        // Serializes every page callback, so the plain `var`s below need no locking.
        let queue = Queue(name: "kwgram.export.history")
        var collected: [Message] = []
        var pageDisposables: [Disposable] = []
        var isDone = false
        var currentAnchor: MessageId?

        // Kick off the next page. Each page appends its messages, then either schedules the
        // previous (earlier) page via its oldest message, or — once a page reports no earlier
        // hole — emits the assembled history exactly once and tears down every page
        // subscription. Driven off `currentAnchor` (a flat loop, not recursion) so this stays
        // stack-safe for arbitrarily large chats.
        func startNextPage() {
            guard !isDone else {
                return
            }
            let anchor = currentAnchor
            let pageSignal: Signal<(MessageHistoryView, ViewUpdateType, InitialMessageHistoryData?), NoError>
            if let anchor {
                pageSignal = context.account.postbox.aroundIdMessageHistoryViewForLocation(
                    location,
                    ignoreMessagesInTimestampRange: nil,
                    ignoreMessageIds: [],
                    count: pageSize,
                    trackHoles: true,
                    clipHoles: false,
                    ignoreRelatedChats: false,
                    messageId: anchor,
                    topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud],
                    tag: nil,
                    appendMessagesFromTheSameGroup: false,
                    namespaces: .just(Namespaces.Message.Cloud),
                    orderStatistics: [],
                    additionalData: []
                )
            } else {
                pageSignal = context.account.postbox.aroundMessageHistoryViewForLocation(
                    location,
                    ignoreMessagesInTimestampRange: nil,
                    ignoreMessageIds: [],
                    anchor: .upperBound,
                    count: pageSize,
                    trackHoles: true,
                    clipHoles: false,
                    ignoreRelatedChats: false,
                    fixedCombinedReadStates: nil,
                    topTaggedMessageIdNamespaces: [Namespaces.Message.Cloud],
                    tag: nil,
                    appendMessagesFromTheSameGroup: false,
                    namespaces: .just(Namespaces.Message.Cloud),
                    orderStatistics: [],
                    additionalData: []
                )
            }

            let pageDisposable = (pageSignal
            |> deliverOn(queue)).start(next: { view, _, _ in
                guard !isDone else {
                    return
                }
                let messages = view.entries.map { $0.message }
                collected.append(contentsOf: messages)

                if view.holeEarlier, let oldest = messages.first {
                    currentAnchor = oldest.id
                    startNextPage()
                } else {
                    // No more history — emit once, then dispose every page subscription.
                    isDone = true
                    var seen = Set<MessageId>()
                    let ordered = collected.reversed().filter { seen.insert($0.id).inserted }
                    subscriber.putNext(Array(ordered))
                    subscriber.putCompletion()
                    for disposable in pageDisposables {
                        disposable.dispose()
                    }
                    pageDisposables = []
                }
            })
            pageDisposables.append(pageDisposable)
        }

        startNextPage()
        return ActionDisposable {
            isDone = true
            for disposable in pageDisposables {
                disposable.dispose()
            }
        }
    }
}

/// Turns loaded messages into the .txt payload. `accountPeerId` is used to label the user's own
/// messages as "Вы"; everyone else is labelled by their display title.
private func kwGramExportText(messages: [Message], accountPeerId: PeerId) -> String {
    var lines: [String] = []
    lines.reserveCapacity(messages.count)
    for (i, message) in messages.enumerated() {
        let name: String
        if let author = message.author {
            if author.id == accountPeerId {
                name = "Вы"
            } else {
                name = EnginePeer(author).compactDisplayTitle
            }
        } else {
            name = "Система"
        }
        lines.append(kwGramExportLine(index: i + 1, name: name, timestamp: message.timestamp, text: message.text))
    }
    return lines.joined(separator: "\n")
}

/// Writes `text` to a temporary .txt file, wraps it as a local file resource, and enqueues it
/// to Saved Messages (Избранное). Reports the filename via `completion` on the main queue.
private func kwGramSendExportToSavedMessages(context: AccountContext, text: String, filename: String, completion: @escaping (Bool) -> Void) {
    let data = Data(text.utf8)
    let path = NSTemporaryDirectory().appending(filename)
    do {
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    } catch {
        completion(false)
        return
    }

    let resourceId = Int64.random(in: Int64.min ... Int64.max)
    let resource = LocalFileReferenceMediaResource(
        localFilePath: path,
        randomId: resourceId
    )

    let file = TelegramMediaFile(
        fileId: EngineMedia.Id(namespace: Namespaces.Media.LocalFile, id: resourceId),
        partialReference: nil,
        resource: resource,
        previewRepresentations: [],
        videoThumbnails: [],
        immediateThumbnailData: nil,
        mimeType: "text/plain",
        size: Int64(data.count),
        attributes: [.FileName(fileName: filename)],
        alternativeRepresentations: []
    )

    let _ = context.engine.messages.enqueueOutgoingMessage(
        to: context.account.peerId,
        replyTo: nil,
        content: .file(FileMediaReference.standalone(media: file))
    ).start()
    completion(true)
}

/// Reached from "Чаты" → "Экспорт чата в .txt". Opens a single-chat picker, loads that chat's
/// whole history, formats it, and sends the .txt to Избранное (Saved Messages).
public func kwGramExportChatAction(context: AccountContext, presentController: @escaping (ViewController) -> Void, presentTooltip: @escaping (String) -> Void) {
    let selectionController = context.sharedContext.makeContactMultiselectionController(ContactMultiselectionControllerParams(
        context: context,
        mode: .chatSelection(ContactMultiselectionControllerMode.ChatSelection(
            title: "Экспорт чата",
            searchPlaceholder: "Поиск",
            selectedChats: [],
            additionalCategories: nil,
            chatListFilters: nil
        )),
        filters: [.excludeSelf]
    ))
    selectionController.navigationPresentation = .modal

    let _ = (selectionController.result
    |> take(1)
    |> deliverOnMainQueue).start(next: { [weak selectionController] result in
        selectionController?.dismiss()

        var peerId: PeerId?
        if case let .result(peerIds, _) = result {
            for item in peerIds {
                if case let .peer(id) = item {
                    peerId = id
                    break
                }
            }
        }
        guard let peerId else {
            return
        }

        presentTooltip("Готовлю экспорт…")

        let accountPeerId = context.account.peerId
        let title = EnginePeer(PeerId(peerId)).compactDisplayTitle
        let safeTitle = title.isEmpty ? "chat" : title

        let _ = (kwGramLoadAllMessages(context: context, peerId: peerId, threadId: nil)
        |> deliverOnMainQueue).start(next: { messages in
            if messages.isEmpty {
                presentTooltip("В этом чате нет сообщений для экспорта.")
                return
            }
            let body = kwGramExportText(messages: messages, accountPeerId: accountPeerId)
            let filename = "\(safeTitle).txt"
            kwGramSendExportToSavedMessages(context: context, text: body, filename: filename) { sent in
                if sent {
                    presentTooltip("«\(filename)» отправлен в Избранное.")
                } else {
                    presentTooltip("Не удалось сохранить файл экспорта.")
                }
            }
        })
    })

    presentController(selectionController)
}
