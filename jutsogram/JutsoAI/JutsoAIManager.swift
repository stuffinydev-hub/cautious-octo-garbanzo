import Foundation
import SwiftSignalKit

/// JutsoAI Manager - Manages AI chat functionality
public final class JutsoAIManager {
    public static let shared = JutsoAIManager()
    
    // MARK: - AI Models
    public enum AIModel: String, CaseIterable {
        case gpt4o = "GPT-4o"
        case gpt4 = "GPT-4"
        case o3 = "o3"
        case gemini25Flash = "Gemini 2.5 Flash"
        case gemini25FlashLite = "Gemini 2.5 Flash-Lite"
        case gemini25Pro = "Gemini 2.5 Pro"
        case claude37Sonnet = "Claude 3.7 Sonnet"
        case deepSeekV3 = "DeepSeek V3"
        case deepSeekR1 = "DeepSeek R1"
        case grok4 = "Grok 4"
        
        public var displayName: String {
            return self.rawValue
        }
    }
    
    // MARK: - Properties
    private var selectedModel: AIModel = .gemini25FlashLite
    private var conversationHistory: [[String: String]] = []
    
    private init() {
        loadSettings()
    }
    
    // MARK: - Settings
    private enum Keys {
        static let selectedModel = "JutsoAI.selectedModel"
        static let conversationHistory = "JutsoAI.conversationHistory"
    }
    
    private func loadSettings() {
        if let modelString = UserDefaults.standard.string(forKey: Keys.selectedModel),
           let model = AIModel(rawValue: modelString) {
            self.selectedModel = model
        }
        
        if let historyData = UserDefaults.standard.data(forKey: Keys.conversationHistory),
           let history = try? JSONDecoder().decode([[String: String]].self, from: historyData) {
            self.conversationHistory = history
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: Keys.selectedModel)
        
        if let historyData = try? JSONEncoder().encode(conversationHistory) {
            UserDefaults.standard.set(historyData, forKey: Keys.conversationHistory)
        }
        
        NotificationCenter.default.post(name: JutsoAIManager.settingsChangedNotification, object: nil)
    }
    
    // MARK: - Public API
    public var currentModel: AIModel {
        get { return selectedModel }
        set {
            selectedModel = newValue
            saveSettings()
        }
    }
    
    public func sendMessage(_ message: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Add user message to history
        conversationHistory.append(["role": "user", "content": message])
        saveSettings()
        
        // Simulate AI response (replace with actual API call)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            let response = "Привет! Я JutsoAI, ваш персональный помощник. Вы написали: \"\(message)\". Как я могу вам помочь?"
            
            self?.conversationHistory.append(["role": "assistant", "content": response])
            self?.saveSettings()
            
            DispatchQueue.main.async {
                completion(.success(response))
            }
        }
    }
    
    public func getConversationHistory() -> [[String: String]] {
        return conversationHistory
    }
    
    public func clearHistory() {
        conversationHistory.removeAll()
        saveSettings()
    }
    
    // MARK: - Notifications
    public static let settingsChangedNotification = Notification.Name("JutsoAISettingsChanged")
}
