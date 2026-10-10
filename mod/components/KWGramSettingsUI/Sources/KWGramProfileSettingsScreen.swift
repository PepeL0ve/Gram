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
    case colorsRow(String, String)
    case timeToggle(Bool)
    case timeFooter(String)

    var section: ItemListSectionId {
        switch self {
        case .numberEditor, .ratingEditor, .colorsRow:
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
        case .colorsRow:
            return 2
        case .timeToggle:
            return 3
        case .timeFooter:
            return 4
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
        case let .colorsRow(title, label):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "paintpalette.fill", backgroundColor: UIColor(rgb: 0xaf52de)),
                title: title,
                titleFont: .bold,
                label: label,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openColorPicker()
                }
            )
        case let .timeToggle(value):
            return ItemListSwitchItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "clock.fill", backgroundColor: UIColor(rgb: 0x0a84ff)),
                title: "Время в ник",
                text: "Показывает текущее московское время в фамилии вашего профиля и обновляет его каждую минуту.",
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
    let openColorPicker: () -> Void
    let toggleTimeInNickname: (Bool) -> Void

    init(openNumberEditor: @escaping () -> Void, openRatingEditor: @escaping () -> Void, openColorPicker: @escaping () -> Void, toggleTimeInNickname: @escaping (Bool) -> Void) {
        self.openNumberEditor = openNumberEditor
        self.openRatingEditor = openRatingEditor
        self.openColorPicker = openColorPicker
        self.toggleTimeInNickname = toggleTimeInNickname
    }
}

private func kwGramProfileEntries(profileVisuals: KWGramProfileVisualState, timeInNicknameEnabled: Bool, colors: KWGramPersonalColors) -> [KWGramProfileEntry] {
    let visualNumberLabel = profileVisuals.anonymousNumberEnabled ? profileVisuals.anonymousNumber : "Настроить"
    let visualRatingLabel = profileVisuals.ratingEnabled ? "Уровень \(max(1, profileVisuals.ratingValue))" : "Настроить"
    var colorsParts: [String] = []
    if let nameIndex = colors.nameColorIndex {
        colorsParts.append("имя \(nameIndex + 1)")
    }
    if let profileIndex = colors.profileColorIndex {
        colorsParts.append("профиль \(profileIndex + 1)")
    }
    let colorsLabel = colorsParts.isEmpty ? "Настроить" : colorsParts.joined(separator: " · ")
    return [
        .numberEditor("Визуальный +888", visualNumberLabel),
        .ratingEditor("Визуальный рейтинг", visualRatingLabel),
        .colorsRow("Персональные цвета", colorsLabel),
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
        openColorPicker: {
            pushControllerImpl?(kwGramPersonalColorPickerController(context: context))
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
        KWGramCore.rawSettingsSignal(postbox: context.account.postbox),
        KWGramPersonalColorStore.signal(postbox: context.account.postbox)
    )
    |> deliverOnMainQueue
    |> map { presentationData, profileVisuals, settings, colors -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
            entries: kwGramProfileEntries(profileVisuals: profileVisuals, timeInNicknameEnabled: settings.timeInNicknameEnabled, colors: colors),
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
