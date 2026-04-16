import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import AlertUI

private final class JutsoAIStore {
    static let shared = JutsoAIStore()

    struct Message: Codable {
        let role: String
        let text: String
    }

    enum Model: String, CaseIterable, Codable {
        case gpt5 = "GPT-5"
        case gpt4o = "GPT-4o"
        case o3 = "o3"
        case gemini25Flash = "Gemini 2.5 Flash"
        case gemini25FlashLite = "Gemini 2.5 Flash-Lite"
        case gemini25Pro = "Gemini 2.5 Pro"
        case claude37Sonnet = "Claude 3.7 Sonnet"
        case deepSeekV3 = "DeepSeek V3"
        case deepSeekR1 = "DeepSeek R1"
        case grok4 = "Grok 4"
    }

    private enum Keys {
        static let model = "JutsoAI.Store.Model"
        static let history = "JutsoAI.Store.History"
    }

    private let defaults = UserDefaults.standard
    private(set) var model: Model = .gemini25FlashLite
    private(set) var history: [Message] = []

    private init() {
        if let storedModel = defaults.string(forKey: Keys.model), let model = Model(rawValue: storedModel) {
            self.model = model
        }
        if let data = defaults.data(forKey: Keys.history), let history = try? JSONDecoder().decode([Message].self, from: data) {
            self.history = history
        }
    }

    func setModel(_ model: Model) {
        self.model = model
        self.defaults.set(model.rawValue, forKey: Keys.model)
    }

    func clear() {
        self.history.removeAll()
        self.save()
    }

    func send(message: String, completion: @escaping (String) -> Void) {
        self.history.append(Message(role: "user", text: message))
        self.save()

        let response = self.makeResponse(for: message)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.history.append(Message(role: "assistant", text: response))
            self.save()
            completion(response)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(self.history) {
            self.defaults.set(data, forKey: Keys.history)
        }
    }

    private func makeResponse(for message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Напишите вопрос, и я помогу с идеей, текстом или быстрым разбором."
        }

        return "Модель `\(self.model.rawValue)` получила ваш запрос: «\(trimmed)».\n\nЭто локальный demo-чат в стиле Telegram: история сохраняется на устройстве, модель можно переключать, а позже сюда можно подключить реальный API."
    }
}

private enum JutsoAISection: Int32 {
    case hero
    case conversation
    case composer
    case actions
}

private enum JutsoAIEntry: ItemListNodeEntry {
    case hero(PresentationTheme, String)
    case model(PresentationTheme, String, String)
    case message(Int32, PresentationTheme, String)
    case input(PresentationTheme, String)
    case send(PresentationTheme, String, Bool)
    case clear(PresentationTheme, String, Bool)

    var section: ItemListSectionId {
        switch self {
        case .hero:
            return JutsoAISection.hero.rawValue
        case .model, .message:
            return JutsoAISection.conversation.rawValue
        case .input, .send:
            return JutsoAISection.composer.rawValue
        case .clear:
            return JutsoAISection.actions.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .hero:
            return 0
        case .model:
            return 1
        case let .message(index, _, _):
            return 100 + index
        case .input:
            return 10_000
        case .send:
            return 10_001
        case .clear:
            return 10_002
        }
    }

    static func ==(lhs: JutsoAIEntry, rhs: JutsoAIEntry) -> Bool {
        switch lhs {
        case let .hero(lhsTheme, lhsText):
            if case let .hero(rhsTheme, rhsText) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText
            }
            return false
        case let .model(lhsTheme, lhsTitle, lhsValue):
            if case let .model(rhsTheme, rhsTitle, rhsValue) = rhs {
                return lhsTheme === rhsTheme && lhsTitle == rhsTitle && lhsValue == rhsValue
            }
            return false
        case let .message(lhsIndex, lhsTheme, lhsText):
            if case let .message(rhsIndex, rhsTheme, rhsText) = rhs {
                return lhsIndex == rhsIndex && lhsTheme === rhsTheme && lhsText == rhsText
            }
            return false
        case let .input(lhsTheme, lhsText):
            if case let .input(rhsTheme, rhsText) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText
            }
            return false
        case let .send(lhsTheme, lhsText, lhsEnabled):
            if case let .send(rhsTheme, rhsText, rhsEnabled) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText && lhsEnabled == rhsEnabled
            }
            return false
        case let .clear(lhsTheme, lhsText, lhsEnabled):
            if case let .clear(rhsTheme, rhsText, rhsEnabled) = rhs {
                return lhsTheme === rhsTheme && lhsText == rhsText && lhsEnabled == rhsEnabled
            }
            return false
        }
    }

    static func <(lhs: JutsoAIEntry, rhs: JutsoAIEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! JutsoAIArguments
        switch self {
        case let .hero(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .model(_, title, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: title,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: { arguments.openModelPicker() }
            )
        case let .message(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .markdown(text), sectionId: self.section)
        case let .input(_, text):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(),
                text: text,
                placeholder: "Введите ваш вопрос",
                type: .regular(capitalization: true, autocorrection: true),
                returnKeyType: .send,
                clearType: .always,
                sectionId: self.section,
                textUpdated: { arguments.updateInput($0) },
                action: { arguments.send() }
            )
        case let .send(_, title, enabled):
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                kind: enabled ? .generic : .disabled,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: { if enabled { arguments.send() } }
            )
        case let .clear(_, title, enabled):
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                kind: enabled ? .generic : .disabled,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: { if enabled { arguments.clearHistory() } }
            )
        }
    }
}

private struct JutsoAIState: Equatable {
    var selectedModel: JutsoAIStore.Model
    var history: [JutsoAIStore.Message]
    var inputText: String
    var isSending: Bool

    static func initial() -> JutsoAIState {
        return JutsoAIState(
            selectedModel: JutsoAIStore.shared.model,
            history: JutsoAIStore.shared.history,
            inputText: "",
            isSending: false
        )
    }
}

private final class JutsoAIArguments {
    let updateInput: (String) -> Void
    let send: () -> Void
    let clearHistory: () -> Void
    let openModelPicker: () -> Void

    init(updateInput: @escaping (String) -> Void, send: @escaping () -> Void, clearHistory: @escaping () -> Void, openModelPicker: @escaping () -> Void) {
        self.updateInput = updateInput
        self.send = send
        self.clearHistory = clearHistory
        self.openModelPicker = openModelPicker
    }
}

private func jutsoAIEntries(presentationData: PresentationData, state: JutsoAIState) -> [JutsoAIEntry] {
    var entries: [JutsoAIEntry] = []

    entries.append(.hero(presentationData.theme, "**jutsoAI**\n\nПривет! Чем я могу помочь вам сегодня?\n\nЛокальный AI‑чат в стиле Telegram. История сохраняется на устройстве."))
    entries.append(.model(presentationData.theme, "Модель", state.selectedModel.rawValue))

    if state.history.isEmpty {
        entries.append(.message(0, presentationData.theme, "_Диалог пока пуст._\n\nНапишите вопрос ниже."))
    } else {
        for (index, message) in state.history.enumerated() {
            let prefix = message.role == "assistant" ? "**jutsoAI**" : "**Вы**"
            entries.append(.message(Int32(index), presentationData.theme, "\(prefix)\n\(message.text)"))
        }
    }

    entries.append(.input(presentationData.theme, state.inputText))
    entries.append(.send(presentationData.theme, state.isSending ? "Генерируется ответ..." : "Отправить", !state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !state.isSending))
    entries.append(.clear(presentationData.theme, "Очистить историю", !state.history.isEmpty && !state.isSending))

    return entries
}

public func jutsoAIController(context: AccountContext) -> ViewController {
    var presentImpl: ((ViewController) -> Void)?

    let stateValue = Atomic(value: JutsoAIState.initial())
    let statePromise = ValuePromise(JutsoAIState.initial(), ignoreRepeated: true)

    func updateState(_ f: (inout JutsoAIState) -> Void) {
        let updated = stateValue.modify { current in
            var current = current
            f(&current)
            return current
        }
        statePromise.set(updated)
    }

    func reloadState() {
        updateState { state in
            state.selectedModel = JutsoAIStore.shared.model
            state.history = JutsoAIStore.shared.history
        }
    }

    let arguments = JutsoAIArguments(
        updateInput: { value in updateState { $0.inputText = value } },
        send: {
            let currentState = stateValue.with { $0 }
            let text = currentState.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, !currentState.isSending else { return }

            updateState { state in
                state.isSending = true
                state.inputText = ""
                state.history = JutsoAIStore.shared.history + [JutsoAIStore.Message(role: "user", text: text)]
            }

            JutsoAIStore.shared.send(message: text) { _ in
                updateState { state in
                    state.isSending = false
                    state.selectedModel = JutsoAIStore.shared.model
                    state.history = JutsoAIStore.shared.history
                }
            }
        },
        clearHistory: {
            JutsoAIStore.shared.clear()
            updateState { $0.history = [] }
        },
        openModelPicker: {
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            let actions: [TextAlertAction] = JutsoAIStore.Model.allCases.map { model in
                TextAlertAction(type: model == JutsoAIStore.shared.model ? .defaultAction : .genericAction, title: model.rawValue, action: {
                    JutsoAIStore.shared.setModel(model)
                    updateState { state in
                        state.selectedModel = model
                        state.history = JutsoAIStore.shared.history
                    }
                })
            } + [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {})]

            let controller = textAlertController(
                context: context,
                updatedPresentationData: nil,
                title: "Выберите модель",
                text: "Локальные пресеты (демо).",
                actions: actions
            )
            presentImpl?(controller)
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("AI"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: jutsoAIEntries(presentationData: presentationData, state: state),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.tabBarItem.title = "jutsoAI"
    let tabImage = UIImage(systemName: "sparkles")?.withRenderingMode(.alwaysTemplate)
    controller.tabBarItem.image = tabImage
    controller.tabBarItem.selectedImage = tabImage
    controller.didAppear = { _ in reloadState() }

    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }

    return controller
}

