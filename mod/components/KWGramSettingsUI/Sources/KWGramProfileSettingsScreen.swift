import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import ItemListUI
import PresentationDataUtils
import AccountContext
import KWGramCore

private enum KWGramProfileSection: Int32 {
    case visuals
    case time
}

private enum KWGramProfileEntry: ItemListNodeEntry {
    case numberEditor(String, String)
    case ratingEditor(String, String)
    case timeToggle(Bool)
    case timeFooter(String)

    var section: ItemListSectionId {
        switch self {
        case .numberEditor, .ratingEditor:
            return KWGramProfileSection.visuals.rawValue
        case .timeToggle, .timeFooter:
            return KWGramProfileSection.time.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .numberEditor:
            return 0
        case .ratingEditor:
            return 1
        case .timeToggle:
            return 2
        case .timeFooter:
            return 3
        }
    }

    static func <(lhs: KWGramProfileEntry, rhs: KWGramProfileEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KWGramProfileArguments
        switch self {
        case let .numberEditor(title, label):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "phone.fill", backgroundColor: UIColor(rgb: 0x8e44ec)),
                title: title,
                titleFont: .bold,
                label: label,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openNumberEditor()
                }
            )
        case let .ratingEditor(title, label):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "star.fill", backgroundColor: UIColor(rgb: 0xf5a623)),
                title: title,
                titleFont: .bold,
                label: label,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openRatingEditor()
                }
            )
        case let .timeToggle(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "clock.fill", backgroundColor: UIColor(rgb: 0x0a84ff)),
                title: "Время в ник",
                value: value,
                sectionId: self.section,
                style: .blocks,
                updated: { value in
                    arguments.toggleTimeInNickname(value)
                }
            )
        case let .timeFooter(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private final class KWGramProfileArguments {
    let openNumberEditor: () -> Void
    let openRatingEditor: () -> Void
    let toggleTimeInNickname: (Bool) -> Void

    init(openNumberEditor: @escaping () -> Void, openRatingEditor: @escaping () -> Void, toggleTimeInNickname: @escaping (Bool) -> Void) {
        self.openNumberEditor = openNumberEditor
        self.openRatingEditor = openRatingEditor
        self.toggleTimeInNickname = toggleTimeInNickname
    }
}

private func kwGramProfileEntries(profileVisuals: KWGramProfileVisualState, timeInNicknameEnabled: Bool) -> [KWGramProfileEntry] {
    let visualNumberLabel = profileVisuals.anonymousNumberEnabled ? profileVisuals.anonymousNumber : "Настроить"
    let visualRatingLabel = profileVisuals.ratingEnabled ? "Уровень \(max(1, profileVisuals.ratingValue))" : "Настроить"
    return [
        .numberEditor("Визуальный +888", visualNumberLabel),
        .ratingEditor("Визуальный рейтинг", visualRatingLabel),
        .timeToggle(timeInNicknameEnabled),
        .timeFooter("Пока включено, фамилия в вашем профиле показывает текущее московское время (09:35) и обновляется каждую минуту. При выключении вернётся прежняя фамилия.")
    ]
}

/// The "Профиль" section: profile-local visuals (+888 number and rating — moved here from
/// "Подарки") plus "Время в ник", the one KW Gram function that edits the real account name
/// (see `KWGramTimeInNicknameRuntime` for the engine side of it).
public func kwGramProfileSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = KWGramProfileArguments(
        openNumberEditor: {
            pushControllerImpl?(kwGramProfileNumberEditorController(context: context))
        },
        openRatingEditor: {
            pushControllerImpl?(kwGramProfileRatingEditorController(context: context))
        },
        toggleTimeInNickname: { value in
            let _ = KWGramCore.updateSettingsInteractively(postbox: context.account.postbox, { settings in
                var settings = settings
                settings.timeInNicknameEnabled = value
                return settings
            }).start()
        }
    )

    let signal = combineLatest(
        context.sharedContext.presentationData,
        KWGramProfileVisualStore.signal(postbox: context.account.postbox),
        KWGramCore.rawSettingsSignal(postbox: context.account.postbox)
    )
    |> deliverOnMainQueue
    |> map { presentationData, profileVisuals, settings -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Профиль"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: kwGramProfileEntries(profileVisuals: profileVisuals, timeInNicknameEnabled: settings.timeInNicknameEnabled),
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
