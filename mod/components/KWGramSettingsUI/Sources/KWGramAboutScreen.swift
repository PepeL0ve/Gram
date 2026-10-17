import Foundation
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext

private enum KWGramAboutEntry: ItemListNodeEntry {
    case hero
    case aboutHeader(String)
    case aboutText(String)
    case changelogHeader(String)
    case changelogText(String)

    var section: ItemListSectionId {
        switch self {
        case .hero:
            return 0
        case .aboutHeader, .aboutText:
            return 1
        case .changelogHeader, .changelogText:
            return 2
        }
    }

    var stableId: Int32 {
        switch self {
        case .hero:
            return 0
        case .aboutHeader:
            return 1
        case .aboutText:
            return 2
        case .changelogHeader:
            return 3
        case .changelogText:
            return 4
        }
    }

    static func <(lhs: KWGramAboutEntry, rhs: KWGramAboutEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        switch self {
        case .hero:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: kwGramSettingsIcon(size: 44.0),
                title: "KW Gram",
                titleFont: .bold,
                titleBadge: "MOD",
                label: kwGramVersionString,
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: nil
            )
        case let .aboutHeader(text), let .changelogHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .aboutText(text), let .changelogText(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

/// The hub's hero row opens this on tap — a short "what is this" plus the current release's
/// changelog. Both texts live in `KWGramVersion.swift`, updated on every release.
public func kwGramAboutController(context: AccountContext) -> ViewController {
    let signal = context.sharedContext.presentationData
    |> deliverOnMainQueue
    |> map { presentationData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("О KW Gram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let entries: [KWGramAboutEntry] = [
            .hero,
            .aboutHeader("ЧТО ЭТО"),
            .aboutText("Мод для Telegram-iOS: визуальные и локальные функции поверх настоящего клиента."),
            .changelogHeader("ЧТО В ЭТОЙ ВЕРСИИ"),
            .changelogText(kwGramChangelogText)
        ]
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, ()))
    }

    return ItemListController(context: context, state: signal)
}
