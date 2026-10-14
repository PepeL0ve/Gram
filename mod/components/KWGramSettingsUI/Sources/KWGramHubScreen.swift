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

private enum KWGramHubSection: Int32 {
    case hero
    case search
    case sections
    case status
    case team
}

private enum KWGramHubEntry: ItemListNodeEntry {
    case hero
    case search
    case gifts
    case messages
    case privacy
    case appearance
    case advanced
    case admin
    case profile(Int)
    case status(Int, Int)
    case team

    var section: ItemListSectionId {
        switch self {
        case .hero:
            return KWGramHubSection.hero.rawValue
        case .search:
            return KWGramHubSection.search.rawValue
        case .gifts, .messages, .privacy, .appearance, .advanced, .admin, .profile:
            return KWGramHubSection.sections.rawValue
        case .status:
            return KWGramHubSection.status.rawValue
        case .team:
            return KWGramHubSection.team.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .hero:
            return 0
        case .search:
            return 1
        case .gifts:
            return 2
        case .messages:
            return 3
        case .privacy:
            return 4
        case .appearance:
            return 5
        case .advanced:
            return 6
        case .admin:
            return 7
        case .profile:
            return 8
        case .status:
            return 9
        case .team:
            return 10
        }
    }

    static func <(lhs: KWGramHubEntry, rhs: KWGramHubEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! KWGramHubArguments
        switch self {
        case .hero:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: kwGramSettingsIcon(),
                title: "KW Gram",
                titleFont: .bold,
                titleBadge: "MOD",
                label: kwGramVersionString,
                additionalDetailLabel: "Расширяй. Скрывай. Контролируй.",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: {
                    arguments.openAbout()
                }
            )
        case .search:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "magnifyingglass", backgroundColor: UIColor(rgb: 0x636366)),
                title: "Найти функцию или раздел",
                label: "",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openSearch()
                }
            )
        case .gifts:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "gift.fill", backgroundColor: UIColor(rgb: 0x8e44ec)),
                title: "Визуал",
                titleFont: .bold,
                label: "",
                additionalDetailLabel: "Управление подарками и визуалами",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openGifts()
                }
            )
        case .messages:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "message.fill", backgroundColor: UIColor(rgb: 0x3b82f6)),
                title: "Чаты",
                titleFont: .bold,
                label: "",
                additionalDetailLabel: "Визуальный редактор, история, поиск подарков, мут ЛС",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openMessages()
                }
            )
        case .privacy:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "eye.slash.fill", backgroundColor: UIColor(rgb: 0x34c759)),
                title: "Ghost",
                titleFont: .bold,
                label: "",
                additionalDetailLabel: "Скрытые функции и защита",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openGhost()
                }
            )
        case .appearance:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "paintbrush.fill", backgroundColor: UIColor(rgb: 0xff9500)),
                title: "Внешний вид",
                titleFont: .bold,
                label: "",
                additionalDetailLabel: "Темы, иконки, интерфейс",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openAppearance()
                }
            )
        case .advanced:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "gearshape.fill", backgroundColor: UIColor(rgb: 0x8e8e93)),
                title: "Дополнительно",
                titleFont: .bold,
                label: "",
                additionalDetailLabel: "Другие возможности KW Gram",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openAdditional()
                }
            )
        case .admin:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "lock.shield.fill", backgroundColor: UIColor(rgb: 0xff3b30)),
                title: "Админ-панель",
                titleFont: .bold,
                label: "",
                additionalDetailLabel: "Управление подписками",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openAdmin()
                }
            )
        case let .profile(activeCount):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "person.fill", backgroundColor: UIColor(rgb: 0x5856d6)),
                title: "Профиль",
                titleFont: .bold,
                label: "",
                additionalDetailLabel: "\(activeCount) из 3 функций активны",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openProfile()
                }
            )
        case let .status(activeCount, totalCount):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: generateKWGramSectionIcon(systemName: "checkmark.shield.fill", backgroundColor: UIColor(rgb: 0x8e44ec)),
                title: "Статус",
                titleFont: .bold,
                label: "",
                additionalDetailLabel: "\(activeCount) из \(totalCount) функций активны",
                additionalDetailLabelColor: activeCount == totalCount ? .constructive : .generic,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openStatus()
                }
            )
        case .team:
            return ItemListDisclosureItem(
                presentationData: presentationData,
                systemStyle: .glass,
                icon: kwGramSettingsIcon(),
                title: "KW Gram Team",
                label: "",
                additionalDetailLabel: "Сделано с 💜 для тебя",
                sectionId: self.section,
                style: .blocks,
                disclosureStyle: .none,
                action: {
                    arguments.openSupport()
                }
            )
        }
    }
}

private final class KWGramHubArguments {
    let openGifts: () -> Void
    let openMessages: () -> Void
    let openGhost: () -> Void
    let openAppearance: () -> Void
    let openAdditional: () -> Void
    let openAdmin: () -> Void
    let openProfile: () -> Void
    let openStatus: () -> Void
    let openAbout: () -> Void
    let openSupport: () -> Void
    let openSearch: () -> Void

    init(openGifts: @escaping () -> Void, openMessages: @escaping () -> Void, openGhost: @escaping () -> Void, openAppearance: @escaping () -> Void, openAdditional: @escaping () -> Void, openAdmin: @escaping () -> Void, openProfile: @escaping () -> Void, openStatus: @escaping () -> Void, openAbout: @escaping () -> Void, openSearch: @escaping () -> Void, openSupport: @escaping () -> Void) {
        self.openGifts = openGifts
        self.openMessages = openMessages
        self.openGhost = openGhost
        self.openAppearance = openAppearance
        self.openAdditional = openAdditional
        self.openAdmin = openAdmin
        self.openProfile = openProfile
        self.openStatus = openStatus
        self.openAbout = openAbout
        self.openSupport = openSupport
        self.openSearch = openSearch
    }
}

/// KW Gram's own Telegram channel and the support/donations contact — kept in one place
/// since the "KW Gram Team" row's action sheet is the only thing that uses them.
private let kwGramChannelUrl = "https://t.me/FLYXSE_README"
private let kwGramDonateUrl = "https://t.me/FLYXSE"

private func kwGramHubEntries(settings: KWGramSettings, profileVisuals: KWGramProfileVisualState, isAdmin: Bool) -> [KWGramHubEntry] {
    let toggles = [
        settings.phantomGiftsEnabled,
        settings.fakeStarsDisplayEnabled,
        settings.fakeTonDisplayEnabled,
        settings.fromHimGiftsEnabled,
        profileVisuals.anonymousNumberEnabled,
        profileVisuals.ratingEnabled,
        settings.timeInNicknameEnabled,
        settings.antiDeleteMessagesEnabled,
        settings.visualEditEnabled,
        settings.ghostModeEnabled
    ]
    let activeCount = toggles.filter { $0 }.count
    var entries: [KWGramHubEntry] = [
        .hero,
        .search,
        .gifts,
        .messages,
        .privacy,
        .appearance,
        .advanced
    ]
    if isAdmin {
        entries.append(.admin)
    }
    let profileActiveCount = [
        profileVisuals.anonymousNumberEnabled,
        profileVisuals.ratingEnabled,
        settings.timeInNicknameEnabled
    ].filter { $0 }.count
    entries.append(.profile(profileActiveCount))
    entries.append(.status(activeCount, toggles.count))
    entries.append(.team)
    return entries
}

/// The KW Gram root screen: a hub of sections rather than one long list, so unrelated
/// features (gifts/balances, message history, and whatever future KW Gram screens need) each
/// get their own page instead of piling into a single scroll.
public func kwGramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    var navigationControllerImpl: (() -> NavigationController?)?

    let arguments = KWGramHubArguments(
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
        openGhost: {
            kwGramGateSection(context: context, section: .ghost) {
                pushControllerImpl?(kwGramGhostSettingsController(context: context))
            }
        },
        openAppearance: {
            pushControllerImpl?(kwGramAppearanceController(context: context))
        },
        openAdditional: {
            pushControllerImpl?(kwGramAdditionalSettingsController(context: context))
        },
        openAdmin: {
            pushControllerImpl?(kwGramAdminController(context: context))
        },
        openProfile: {
            pushControllerImpl?(kwGramProfileSettingsController(context: context))
        },
        openStatus: {
            pushControllerImpl?(kwGramStatusController(context: context))
        },
        openAbout: {
            pushControllerImpl?(kwGramAboutController(context: context))
        },
        openSearch: {
            pushControllerImpl?(kwGramSearchController(context: context))
        },
        openSupport: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }

            let openChannel: () -> Void = {
                guard let navigationController = navigationControllerImpl?() else {
                    return
                }
                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: kwGramChannelUrl, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
            }

            let openDonateChat: () -> Void = {
                guard let navigationController = navigationControllerImpl?() else {
                    return
                }
                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: kwGramDonateUrl, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
            }

            let mainSheet = ActionSheetController(presentationData: presentationData)
            mainSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: "Наш канал", color: .accent, action: { [weak mainSheet] in
                        mainSheet?.dismissAnimated()
                        openChannel()
                    }),
                    ActionSheetButtonItem(title: "Поддержать проект 💜", color: .accent, action: { [weak mainSheet] in
                        mainSheet?.dismissAnimated()
                        openDonateChat()
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak mainSheet] in
                        mainSheet?.dismissAnimated()
                    })
                ])
            ])
            presentControllerImpl?(mainSheet)
        }
    )

    let isAdmin = context.account.peerId.id._internalGetInt64Value() == KWGramSubscriptionAPI.adminAccountId

    // A full ban blocks the hub itself, not just its sections — checked once per open rather
    // than on every redraw, same one-shot pattern as kwGramGateSection.
    let _ = (KWGramSubscriptionAPI.fetchBanStatus(userId: context.account.peerId.id._internalGetInt64Value())
    |> deliverOnMainQueue).start(next: { status in
        if let reason = status.full {
            kwGramPresentBannedScreen(context: context, reason: reason)
        }
    })

    let signal = combineLatest(
        context.sharedContext.presentationData,
        KWGramCore.settingsSignal(postbox: context.account.postbox),
        KWGramProfileVisualStore.signal(postbox: context.account.postbox)
    )
    |> deliverOnMainQueue
    |> map { presentationData, settings, profileVisuals -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("KW Gram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: false
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: kwGramHubEntries(settings: settings, profileVisuals: profileVisuals, isAdmin: isAdmin),
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
    navigationControllerImpl = { [weak controller] in
        return controller?.navigationController as? NavigationController
    }
    return controller
}
