import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import KWGramCore

/// One searchable KW Gram function: what it's called, a short description of what it does, and
/// which section it lives in — plus how to open that section. `keywords` widens matching beyond
/// the visible title (synonyms, English names) so the search "guesses" the section as closely as
/// possible.
private struct KWGramSearchItem {
    let title: String
    let subtitle: String
    let sectionName: String
    let keywords: String
    let open: () -> Void
}

private final class KWGramSearchArguments {
    let updateQuery: (String) -> Void
    let selectResult: (Int) -> Void

    init(updateQuery: @escaping (String) -> Void, selectResult: @escaping (Int) -> Void) {
        self.updateQuery = updateQuery
        self.selectResult = selectResult
    }
}

private enum KWGramSearchSection: Int32 {
    case field
    case results
}

private enum KWGramSearchEntry: ItemListNodeEntry {
    case field(String)
    case empty(String)
    case result(Int, String, String, String)

    var section: ItemListSectionId {
        switch self {
        case .field:
            return KWGramSearchSection.field.rawValue
        case .empty, .result:
            return KWGramSearchSection.results.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .field:
            return 0
        case .empty:
            return 1
        case let .result(index, _, _, _):
            return 100 + Int32(index)
        }
    }

    static func <(lhs: KWGramSearchEntry, rhs: KWGramSearchEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KWGramSearchArguments
        switch self {
        case let .field(text):
            return ItemListSingleLineInputItem(presentationData: presentationData, title: NSAttributedString(string: ""), text: text, placeholder: "Найти функцию или раздел", type: .regular(capitalization: false, autocorrection: false), clearType: .always, sectionId: self.section, textUpdated: { value in
                arguments.updateQuery(value)
            }, action: {})
        case let .empty(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .result(index, title, subtitle, sectionName):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                titleFont: .bold,
                label: sectionName,
                additionalDetailLabel: subtitle,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.selectResult(index)
                }
            )
        }
    }
}

private func kwGramSearchMatches(index: [KWGramSearchItem], query: String) -> [Int] {
    let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if q.isEmpty {
        // No query yet — show everything so the screen doubles as a full index.
        return Array(index.indices)
    }
    let terms = q.split(separator: " ").map(String.init)
    var scored: [(Int, Int)] = []
    for (i, item) in index.enumerated() {
        let haystack = "\(item.title) \(item.subtitle) \(item.sectionName) \(item.keywords)".lowercased()
        var score = 0
        var matchedAll = true
        for term in terms {
            if let range = haystack.range(of: term) {
                score += 1
                if item.title.lowercased().hasPrefix(term) {
                    score += 3
                } else if haystack.distance(from: haystack.startIndex, to: range.lowerBound) < item.title.count {
                    score += 1
                }
            } else {
                matchedAll = false
            }
        }
        if matchedAll {
            scored.append((i, score))
        }
    }
    scored.sort { $0.1 > $1.1 }
    return scored.map { $0.0 }
}

/// "Поиск" — reached from the oval search row at the top of the hub. Type a function or a
/// section and it fuzzily matches KW Gram's whole feature index, showing each hit's section
/// and what it does; tapping opens that section (the most specific screen the function lives in).
public func kwGramSearchController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    let queryPromise = ValuePromise<String>("", ignoreRepeated: true)

    let openGifts: () -> Void = { pushControllerImpl?(kwGramGiftsSettingsController(context: context)) }
    let openMessages: () -> Void = { pushControllerImpl?(kwGramMessagesSettingsController(context: context)) }
    let openProfile: () -> Void = { pushControllerImpl?(kwGramProfileSettingsController(context: context)) }
    let openGhost: () -> Void = { pushControllerImpl?(kwGramGhostSettingsController(context: context)) }
    let openAdditional: () -> Void = { pushControllerImpl?(kwGramAdditionalSettingsController(context: context)) }
    let openStatus: () -> Void = { pushControllerImpl?(kwGramStatusController(context: context)) }
    let openFakeLocation: () -> Void = { pushControllerImpl?(kwGramFakeLocationController(context: context)) }
    let openChatLock: () -> Void = { pushControllerImpl?(kwGramChatLockController(context: context)) }
    let openAppearance: () -> Void = { pushControllerImpl?(kwGramAppearanceController(context: context)) }
    let openGiftMarket: () -> Void = { pushControllerImpl?(kwGramGiftMarketController(context: context)) }

    let index: [KWGramSearchItem] = [
        KWGramSearchItem(title: "Подарок ему", subtitle: "Визуальная отправка подарка, без списания Stars/TON", sectionName: "Подарки", keywords: "gift подарки маркет фантом", open: openGifts),
        KWGramSearchItem(title: "Подарок мне", subtitle: "Подарок выглядит подаренным вам собеседником", sectionName: "Подарки", keywords: "от него gift получить", open: openGifts),
        KWGramSearchItem(title: "Локальные звёзды", subtitle: "Показывать свой баланс звёзд вместо настоящего", sectionName: "Подарки", keywords: "stars баланс фантом деньги", open: openGifts),
        KWGramSearchItem(title: "Локальные TON/GRAM", subtitle: "Показывать свой баланс TON/GRAM вместо настоящего", sectionName: "Подарки", keywords: "ton gram крипто баланс", open: openGifts),
        KWGramSearchItem(title: "Локальные рубли", subtitle: "Локальная карта для покупки звёзд за рубли", sectionName: "Подарки", keywords: "рубли карта покупка звёзд", open: openGifts),
        KWGramSearchItem(title: "История и статистика", subtitle: "Локальный журнал Stars/TON/рублей: пополнения, покупки, продажи", sectionName: "Подарки", keywords: "ledger история статистика пополнения покупки продажи журнал", open: openGifts),
        KWGramSearchItem(title: "Маркет подарков", subtitle: "Локальный маркет: выставить и снять подарки", sectionName: "Подарки", keywords: "market маркет продать выставить подарки", open: openGiftMarket),
        KWGramSearchItem(title: "Визуальный +888", subtitle: "Локально заменить свой номер в профиле", sectionName: "Профиль", keywords: "888 номер anonymous number профиль", open: openProfile),
        KWGramSearchItem(title: "Визуальный рейтинг", subtitle: "Локальный рейтинг и очки в своём профиле", sectionName: "Профиль", keywords: "rating рейтинг очки уровень профиль", open: openProfile),
        KWGramSearchItem(title: "Время в ник", subtitle: "Показывать московское время в имени вместо фамилии", sectionName: "Профиль", keywords: "время ник имя фамилия москва время nickname", open: openProfile),
        KWGramSearchItem(title: "Удалённые сообщения", subtitle: "Сохранять сообщения, удалённые собеседником", sectionName: "Чаты", keywords: "антиделит recover delete восстановление", open: openMessages),
        KWGramSearchItem(title: "Изменить визуально", subtitle: "Локально править текст и подкладывать фейк-контент", sectionName: "Чаты", keywords: "visual edit фейк текст фото", open: openMessages),
        KWGramSearchItem(title: "Режим призрака", subtitle: "Скрывать прочтение, онлайн, «печатает», истории", sectionName: "Ghost", keywords: "ghost призрак нечиталка онлайн typing", open: openGhost),
        KWGramSearchItem(title: "Не читать сообщения", subtitle: "Не отправлять отметку о прочтении", sectionName: "Ghost", keywords: "прочтение read receipt галочки", open: openGhost),
        KWGramSearchItem(title: "Не отправлять «онлайн»", subtitle: "Не показывать статус в сети", sectionName: "Ghost", keywords: "онлайн online статус", open: openGhost),
        KWGramSearchItem(title: "Изменение голоса", subtitle: "Менять высоту голоса в голосовых сообщениях", sectionName: "Дополнительно", keywords: "voice голос голосовое питч", open: openAdditional),
        KWGramSearchItem(title: "Ускорение загрузки/скачивания", subtitle: "Быстрее передавать файлы", sectionName: "Дополнительно", keywords: "speed скорость upload download турбо", open: openAdditional),
        KWGramSearchItem(title: "Закрепить чаты ∞", subtitle: "Снять лимит на закреплённые чаты", sectionName: "Дополнительно", keywords: "pin закреп бесконечно pinned", open: openAdditional),
        KWGramSearchItem(title: "Легальный премиум", subtitle: "Клиентские премиум-послабления", sectionName: "Дополнительно", keywords: "premium премиум подписка", open: openAdditional),
        KWGramSearchItem(title: "Фейковая геолокация", subtitle: "Подменять геопозицию, в т.ч. в реальном времени", sectionName: "Дополнительно", keywords: "location геолокация карта gps live", open: openFakeLocation),
        KWGramSearchItem(title: "Блокировка чатов", subtitle: "PIN на выбранные чаты", sectionName: "Дополнительно", keywords: "lock пин блокировка chat", open: openChatLock),
        KWGramSearchItem(title: "Иконка приложения", subtitle: "Сменить иконку на домашнем экране", sectionName: "Статус", keywords: "icon иконка appearance", open: openStatus),
        KWGramSearchItem(title: "Подписка (PRO/STANDARD)", subtitle: "Статус подписки и её обновление", sectionName: "Статус", keywords: "premium pro подписка обновить", open: openStatus),
        KWGramSearchItem(title: "Внешний вид", subtitle: "Темы, иконки, интерфейс", sectionName: "Внешний вид", keywords: "appearance тема оформление", open: openAppearance)
    ]

    // The result actions live in `index`; dispatch through a closure that captures it.
    let arguments = KWGramSearchArguments(
        updateQuery: { value in
            queryPromise.set(value)
        },
        selectResult: { i in
            guard i >= 0 && i < index.count else {
                return
            }
            index[i].open()
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        queryPromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, query -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Поиск"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )

        var entries: [KWGramSearchEntry] = []
        entries.append(.field(query))
        let matches = kwGramSearchMatches(index: index, query: query)
        if matches.isEmpty {
            entries.append(.empty("Ничего не найдено. Попробуйте другое слово — например «звёзды», «онлайн» или «геолокация»."))
        } else {
            for i in matches {
                let item = index[i]
                entries.append(.result(i, item.title, item.subtitle, item.sectionName))
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
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    return controller
}
