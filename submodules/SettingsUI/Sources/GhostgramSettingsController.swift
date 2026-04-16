import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import JutsogramFeatures

// MARK: - Entry Definition

private enum hakogramSettingsSection: Int32 {
    case features
}

private enum hakogramSettingsEntry: ItemListNodeEntry {
    case deletedMessages(PresentationTheme, String, String)
    case ghostMode(PresentationTheme, String, String)
    case misc(PresentationTheme, String, String)
    case deviceSpoof(PresentationTheme, String, String)
    case voiceMorpher(PresentationTheme, String, String)
    case sendDelay(PresentationTheme, String, String)
    case jutsoGifts(PresentationTheme, String, String)
    case adminPanel(PresentationTheme, String, String)
    case aboutUs(PresentationTheme, String)
    case info(PresentationTheme, String)
    
    var section: ItemListSectionId {
        return hakogramSettingsSection.features.rawValue
    }
    
    var stableId: Int32 {
        switch self {
        case .deletedMessages:
            return 0
        case .ghostMode:
            return 1
        case .misc:
            return 2
        case .deviceSpoof:
            return 3
        case .voiceMorpher:
            return 4
        case .sendDelay:
            return 5
        case .jutsoGifts:
            return 6
        case .adminPanel:
            return 7
        case .aboutUs:
            return 8
        case .info:
            return 9
        }
    }
    
    static func ==(lhs: hakogramSettingsEntry, rhs: hakogramSettingsEntry) -> Bool {
        switch lhs {
        case let .deletedMessages(lhsTheme, lhsText, lhsValue):
            if case let .deletedMessages(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .ghostMode(lhsTheme, lhsText, lhsValue):
            if case let .ghostMode(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .misc(lhsTheme, lhsText, lhsValue):
            if case let .misc(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .deviceSpoof(lhsTheme, lhsText, lhsValue):
            if case let .deviceSpoof(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .voiceMorpher(lhsTheme, lhsText, lhsValue):
            if case let .voiceMorpher(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .sendDelay(lhsTheme, lhsText, lhsValue):
            if case let .sendDelay(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .jutsoGifts(lhsTheme, lhsText, lhsValue):
            if case let .jutsoGifts(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .adminPanel(lhsTheme, lhsText, lhsValue):
            if case let .adminPanel(rhsTheme, rhsText, rhsValue) = rhs,
               lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                return true
            }
            return false
        case let .aboutUs(lhsTheme, lhsText):
            if case let .aboutUs(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        case let .info(lhsTheme, lhsText):
            if case let .info(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                return true
            }
            return false
        }
    }
    
    static func <(lhs: hakogramSettingsEntry, rhs: hakogramSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! hakogramSettingsControllerArguments
        switch self {
        case let .deletedMessages(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openDeletedMessages()
                }
            )
        case let .ghostMode(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openGhostMode()
                }
            )
        case let .misc(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openMisc()
                }
            )
        case let .deviceSpoof(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openDeviceSpoof()
                }
            )
        case let .voiceMorpher(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openVoiceMorpher()
                }
            )
        case let .sendDelay(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openSendDelay()
                }
            )
        case let .jutsoGifts(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openJutsoGifts()
                }
            )
        case let .adminPanel(_, text, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openAdminPanel()
                }
            )
        case let .aboutUs(_, text):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: text,
                label: "",
                sectionId: self.section,
                style: .blocks,
                action: {
                    arguments.openAboutUs()
                }
            )
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

// MARK: - Arguments

private final class hakogramSettingsControllerArguments {
    let openDeletedMessages: () -> Void
    let openGhostMode: () -> Void
    let openMisc: () -> Void
    let openDeviceSpoof: () -> Void
    let openVoiceMorpher: () -> Void
    let openSendDelay: () -> Void
    let openJutsoGifts: () -> Void
    let openAdminPanel: () -> Void
    let openAboutUs: () -> Void
    
    init(
        openDeletedMessages: @escaping () -> Void,
        openGhostMode: @escaping () -> Void,
        openMisc: @escaping () -> Void,
        openDeviceSpoof: @escaping () -> Void,
        openVoiceMorpher: @escaping () -> Void,
        openSendDelay: @escaping () -> Void,
        openJutsoGifts: @escaping () -> Void,
        openAdminPanel: @escaping () -> Void,
        openAboutUs: @escaping () -> Void
    ) {
        self.openDeletedMessages = openDeletedMessages
        self.openGhostMode = openGhostMode
        self.openMisc = openMisc
        self.openDeviceSpoof = openDeviceSpoof
        self.openVoiceMorpher = openVoiceMorpher
        self.openSendDelay = openSendDelay
        self.openJutsoGifts = openJutsoGifts
        self.openAdminPanel = openAdminPanel
        self.openAboutUs = openAboutUs
    }
}

// MARK: - State

private struct hakogramSettingsState: Equatable {
    var deletedMessagesEnabled: Bool
    var ghostModeEnabled: Bool
    var ghostModeActiveCount: Int
    var miscEnabled: Bool
    var miscActiveCount: Int
    var deviceSpoofEnabled: Bool
    var voiceMorpherEnabled: Bool
    var voiceMorpherPresetName: String
    var sendDelayEnabled: Bool
    var starsBalance: Int
    var adminUnlocked: Bool
    
    static func current() -> hakogramSettingsState {
        let localSnapshot = JutsoLocalFeatures.shared.snapshot()
        return hakogramSettingsState(
            deletedMessagesEnabled: AntiDeleteManager.shared.isEnabled,
            ghostModeEnabled: GhostModeManager.shared.isEnabled,
            ghostModeActiveCount: GhostModeManager.shared.activeFeatureCount,
            miscEnabled: MiscSettingsManager.shared.isEnabled,
            miscActiveCount: MiscSettingsManager.shared.activeFeatureCount,
            deviceSpoofEnabled: DeviceSpoofManager.shared.isEnabled,
            voiceMorpherEnabled: VoiceMorpherManager.shared.isEnabled,
            voiceMorpherPresetName: VoiceMorpherManager.shared.selectedPreset.name,
            sendDelayEnabled: SendDelayManager.shared.isEnabled,
            starsBalance: localSnapshot.starsBalance,
            adminUnlocked: localSnapshot.adminUnlocked
        )
    }
}

// MARK: - Entries builder

private func hakogramSettingsControllerEntries(
    presentationData: PresentationData,
    state: hakogramSettingsState
) -> [hakogramSettingsEntry] {
    var entries: [hakogramSettingsEntry] = []
    
    // Deleted Messages
    let deletedStatus = state.deletedMessagesEnabled ? "Вкл" : "Выкл"
    entries.append(.deletedMessages(presentationData.theme, "Удалённые сообщения", deletedStatus))
    
    // Ghost Mode
    let ghostModeStatus = state.ghostModeEnabled ? "\(state.ghostModeActiveCount)/5" : "Выкл"
    entries.append(.ghostMode(presentationData.theme, "Режим призрака", ghostModeStatus))
    
    // Misc
    let miscStatus = state.miscEnabled ? "\(state.miscActiveCount)/5" : "Выкл"
    entries.append(.misc(presentationData.theme, "Прочее", miscStatus))
    
    // Device Spoofing
    let deviceSpoofStatus = state.deviceSpoofEnabled ? "Вкл" : "Выкл"
    entries.append(.deviceSpoof(presentationData.theme, "Подмена устройства", deviceSpoofStatus))
    
    // Voice Morpher
    let voiceMorpherStatus = state.voiceMorpherEnabled ? state.voiceMorpherPresetName : "Выкл"
    entries.append(.voiceMorpher(presentationData.theme, "Голосовой двойник", voiceMorpherStatus))
    
    // Send Delay
    let sendDelayStatus = state.sendDelayEnabled ? "Вкл" : "Выкл"
    entries.append(.sendDelay(presentationData.theme, "Отложка сообщений", sendDelayStatus))

    // Jutso Gifts
    entries.append(.jutsoGifts(presentationData.theme, "Jutso Gifts", "\(state.starsBalance)⭐️"))

    // Admin panel
    entries.append(.adminPanel(presentationData.theme, "Админ-панель", state.adminUnlocked ? "Открыта" : "По коду"))

    // About us
    entries.append(.aboutUs(presentationData.theme, "О нас"))
    
    // Info
    entries.append(.info(presentationData.theme, "Функции Hakogram и jutsoAI в стиле Telegram: приватность, локальный AI-чат, визуальные звёзды, NFT-подарки и скрытая админ-панель владельца."))
    
    return entries
}

// MARK: - Controller

public func hakogramSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController, Bool) -> Void)?
    
    let stateValue = Atomic(value: hakogramSettingsState.current())
    let statePromise = ValuePromise(hakogramSettingsState.current(), ignoreRepeated: true)
    
    let arguments = hakogramSettingsControllerArguments(
        openDeletedMessages: {
            pushControllerImpl?(deletedMessagesController(context: context), true)
        },
        openGhostMode: {
            pushControllerImpl?(ghostModeController(context: context), true)
        },
        openMisc: {
            pushControllerImpl?(miscController(context: context), true)
        },
        openDeviceSpoof: {
            pushControllerImpl?(deviceSpoofController(context: context), true)
        },
        openVoiceMorpher: {
            pushControllerImpl?(voiceMorpherController(context: context), true)
        },
        openSendDelay: {
            pushControllerImpl?(sendDelayController(context: context), true)
        },
        openJutsoGifts: {
            pushControllerImpl?(jutsoStarsController(context: context), true)
        },
        openAdminPanel: {
            pushControllerImpl?(jutsoAdminAccessController(context: context), true)
        },
        openAboutUs: {
            let url = JutsoLocalFeatures.shared.getAboutLink()
            context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
        }
    )
    
    let signal = combineLatest(
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let entries = hakogramSettingsControllerEntries(presentationData: presentationData, state: state)
        
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("j++gram"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: entries,
            style: .blocks,
            animateChanges: true
        )
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    
    // Refresh state when view appears
    controller.visibleBottomContentOffsetChanged = { _ in }
    controller.didAppear = { _ in
        let newState = hakogramSettingsState.current()
        let _ = stateValue.modify { _ in newState }
        statePromise.set(newState)
    }
    
    pushControllerImpl = { [weak controller] c, animated in
        controller?.push(c)
    }
    return controller
}
