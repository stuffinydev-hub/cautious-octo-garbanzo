import Foundation
import TelegramCore
import SwiftSignalKit

/// Admin Panel Manager - Powerful admin control system
public final class AdminPanelManager {
    public static let shared = AdminPanelManager()
    
    // MARK: - Admin Configuration
    private let ADMIN_USER_ID: Int64 = 0 // SET YOUR TELEGRAM USER ID HERE
    private let ADMIN_API_ENDPOINT = "https://your-server.com/api/admin" // Your backend
    
    // MARK: - User Tracking
    public struct HakogramUser: Codable {
        let userId: Int64
        let phoneNumber: String?
        let username: String?
        let firstName: String
        let lastName: String?
        let deviceModel: String
        let osVersion: String
        let appVersion: String
        let installDate: Date
        let lastActiveDate: Date
        let totalMessages: Int
        let totalGiftsSent: Int
        let totalGiftsReceived: Int
        let starBalance: Int
        let aiMessagesCount: Int
        let activeFeatures: [String]
        let location: String?
        let ipAddress: String?
    }
    
    private var trackedUsers: [Int64: HakogramUser] = [:]
    private var isAdmin: Bool = false
    
    private init() {
        loadData()
        checkAdminStatus()
    }
    
    // MARK: - Admin Check
    private func checkAdminStatus() {
        // Check if current user is admin
        // Replace with actual user ID check
        isAdmin = false // Will be set based on current user
    }
    
    public func isCurrentUserAdmin() -> Bool {
        return isAdmin
    }
    
    // MARK: - User Tracking
    public func trackUser(userId: Int64, phoneNumber: String?, username: String?, firstName: String, lastName: String?) {
        let user = HakogramUser(
            userId: userId,
            phoneNumber: phoneNumber,
            username: username,
            firstName: firstName,
            lastName: lastName,
            deviceModel: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            installDate: Date(),
            lastActiveDate: Date(),
            totalMessages: 0,
            totalGiftsSent: 0,
            totalGiftsReceived: 0,
            starBalance: VirtualStarsManager.shared.getBalance(),
            aiMessagesCount: 0,
            activeFeatures: getActiveFeatures(),
            location: nil,
            ipAddress: nil
        )
        
        trackedUsers[userId] = user
        saveData()
        sendToBackend(user)
    }
    
    public func updateUserActivity(userId: Int64) {
        guard var user = trackedUsers[userId] else { return }
        user = HakogramUser(
            userId: user.userId,
            phoneNumber: user.phoneNumber,
            username: user.username,
            firstName: user.firstName,
            lastName: user.lastName,
            deviceModel: user.deviceModel,
            osVersion: user.osVersion,
            appVersion: user.appVersion,
            installDate: user.installDate,
            lastActiveDate: Date(),
            totalMessages: user.totalMessages + 1,
            totalGiftsSent: user.totalGiftsSent,
            totalGiftsReceived: user.totalGiftsReceived,
            starBalance: VirtualStarsManager.shared.getBalance(),
            aiMessagesCount: user.aiMessagesCount,
            activeFeatures: getActiveFeatures(),
            location: user.location,
            ipAddress: user.ipAddress
        )
        trackedUsers[userId] = user
        saveData()
    }
    
    // MARK: - Admin Functions
    
    /// Get all Hakogram users
    public func getAllUsers() -> [HakogramUser] {
        return Array(trackedUsers.values).sorted { $0.lastActiveDate > $1.lastActiveDate }
    }
    
    /// Get user by ID
    public func getUser(userId: Int64) -> HakogramUser? {
        return trackedUsers[userId]
    }
    
    /// Get total users count
    public func getTotalUsersCount() -> Int {
        return trackedUsers.count
    }
    
    /// Get active users (last 24h)
    public func getActiveUsers() -> [HakogramUser] {
        let yesterday = Date().addingTimeInterval(-86400)
        return trackedUsers.values.filter { $0.lastActiveDate > yesterday }
    }
    
    /// Get users by feature
    public func getUsersByFeature(_ feature: String) -> [HakogramUser] {
        return trackedUsers.values.filter { $0.activeFeatures.contains(feature) }
    }
    
    /// Ban user (disable all features)
    public func banUser(userId: Int64) {
        guard isAdmin else { return }
        UserDefaults.standard.set(true, forKey: "banned_\(userId)")
        NotificationCenter.default.post(name: AdminPanelManager.userBannedNotification, object: nil, userInfo: ["userId": userId])
    }
    
    /// Unban user
    public func unbanUser(userId: Int64) {
        guard isAdmin else { return }
        UserDefaults.standard.removeObject(forKey: "banned_\(userId)")
    }
    
    /// Check if user is banned
    public func isUserBanned(userId: Int64) -> Bool {
        return UserDefaults.standard.bool(forKey: "banned_\(userId)")
    }
    
    /// Grant stars to user
    public func grantStars(userId: Int64, amount: Int) {
        guard isAdmin else { return }
        VirtualStarsManager.shared.addStars(amount)
        NotificationCenter.default.post(
            name: AdminPanelManager.starsGrantedNotification,
            object: nil,
            userInfo: ["userId": userId, "amount": amount]
        )
    }
    
    /// Send broadcast message to all users
    public func sendBroadcast(message: String, completion: @escaping (Bool) -> Void) {
        guard isAdmin else {
            completion(false)
            return
        }
        
        // Send to backend for distribution
        sendBroadcastToBackend(message, completion: completion)
    }
    
    /// Get statistics
    public func getStatistics() -> [String: Any] {
        let users = getAllUsers()
        let activeUsers = getActiveUsers()
        
        return [
            "totalUsers": users.count,
            "activeUsers": activeUsers.count,
            "totalMessages": users.reduce(0) { $0 + $1.totalMessages },
            "totalGiftsSent": users.reduce(0) { $0 + $1.totalGiftsSent },
            "totalStars": users.reduce(0) { $0 + $1.starBalance },
            "totalAIMessages": users.reduce(0) { $0 + $1.aiMessagesCount },
            "ghostModeUsers": getUsersByFeature("GhostMode").count,
            "antiDeleteUsers": getUsersByFeature("AntiDelete").count,
            "voiceMorpherUsers": getUsersByFeature("VoiceMorpher").count
        ]
    }
    
    /// Force update for user
    public func forceUpdate(userId: Int64, message: String) {
        guard isAdmin else { return }
        NotificationCenter.default.post(
            name: AdminPanelManager.forceUpdateNotification,
            object: nil,
            userInfo: ["userId": userId, "message": message]
        )
    }
    
    /// Disable feature for user
    public func disableFeature(userId: Int64, feature: String) {
        guard isAdmin else { return }
        UserDefaults.standard.set(true, forKey: "disabled_\(feature)_\(userId)")
    }
    
    /// Enable feature for user
    public func enableFeature(userId: Int64, feature: String) {
        guard isAdmin else { return }
        UserDefaults.standard.removeObject(forKey: "disabled_\(feature)_\(userId)")
    }
    
    /// Check if feature is disabled for user
    public func isFeatureDisabled(userId: Int64, feature: String) -> Bool {
        return UserDefaults.standard.bool(forKey: "disabled_\(feature)_\(userId)")
    }
    
    /// Get user logs
    public func getUserLogs(userId: Int64) -> [String] {
        if let logs = UserDefaults.standard.array(forKey: "logs_\(userId)") as? [String] {
            return logs
        }
        return []
    }
    
    /// Add log entry
    public func addLog(userId: Int64, message: String) {
        var logs = getUserLogs(userId: userId)
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        logs.append("[\(timestamp)] \(message)")
        
        // Keep only last 1000 logs
        if logs.count > 1000 {
            logs = Array(logs.suffix(1000))
        }
        
        UserDefaults.standard.set(logs, forKey: "logs_\(userId)")
    }
    
    // MARK: - Backend Communication
    private func sendToBackend(_ user: HakogramUser) {
        guard let url = URL(string: ADMIN_API_ENDPOINT + "/track") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let data = try? JSONEncoder().encode(user) {
            request.httpBody = data
            
            URLSession.shared.dataTask(with: request) { _, _, _ in
                // Handle response
            }.resume()
        }
    }
    
    private func sendBroadcastToBackend(_ message: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: ADMIN_API_ENDPOINT + "/broadcast") else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload = ["message": message, "users": trackedUsers.keys.map { $0 }] as [String : Any]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            request.httpBody = data
            
            URLSession.shared.dataTask(with: request) { _, response, _ in
                if let httpResponse = response as? HTTPURLResponse {
                    completion(httpResponse.statusCode == 200)
                } else {
                    completion(false)
                }
            }.resume()
        } else {
            completion(false)
        }
    }
    
    // MARK: - Helper Functions
    private func getActiveFeatures() -> [String] {
        var features: [String] = []
        
        if AntiDeleteManager.shared.isEnabled {
            features.append("AntiDelete")
        }
        if GhostModeManager.shared.isEnabled {
            features.append("GhostMode")
        }
        if VoiceMorpherManager.shared.isEnabled {
            features.append("VoiceMorpher")
        }
        if SendDelayManager.shared.isEnabled {
            features.append("SendDelay")
        }
        
        return features
    }
    
    // MARK: - Data Persistence
    private enum Keys {
        static let trackedUsers = "AdminPanel.trackedUsers"
    }
    
    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: Keys.trackedUsers),
           let users = try? JSONDecoder().decode([Int64: HakogramUser].self, from: data) {
            trackedUsers = users
        }
    }
    
    private func saveData() {
        if let data = try? JSONEncoder().encode(trackedUsers) {
            UserDefaults.standard.set(data, forKey: Keys.trackedUsers)
        }
    }
    
    // MARK: - Notifications
    public static let userBannedNotification = Notification.Name("AdminPanelUserBanned")
    public static let starsGrantedNotification = Notification.Name("AdminPanelStarsGranted")
    public static let forceUpdateNotification = Notification.Name("AdminPanelForceUpdate")
}
