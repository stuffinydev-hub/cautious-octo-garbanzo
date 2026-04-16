import Foundation
import TelegramCore

/// Virtual Stars Manager - Manages local virtual stars and NFT gifts
public final class VirtualStarsManager {
    public static let shared = VirtualStarsManager()
    
    // MARK: - Star Balance
    private var starBalance: Int = 0
    
    // MARK: - Gift Types
    public enum NFTGift: String, Codable, CaseIterable {
        case star = "⭐️ Звезда"
        case heart = "❤️ Сердце"
        case fire = "🔥 Огонь"
        case diamond = "💎 Алмаз"
        case crown = "👑 Корона"
        case rocket = "🚀 Ракета"
        case trophy = "🏆 Трофей"
        case gem = "💠 Драгоценность"
        
        public var cost: Int {
            switch self {
            case .star: return 1
            case .heart: return 5
            case .fire: return 10
            case .diamond: return 25
            case .crown: return 50
            case .rocket: return 75
            case .trophy: return 100
            case .gem: return 150
            }
        }
        
        public var emoji: String {
            switch self {
            case .star: return "⭐️"
            case .heart: return "❤️"
            case .fire: return "🔥"
            case .diamond: return "💎"
            case .crown: return "👑"
            case .rocket: return "🚀"
            case .trophy: return "🏆"
            case .gem: return "💠"
            }
        }
    }
    
    // MARK: - Gift Record
    public struct GiftRecord: Codable {
        let id: String
        let fromUserId: Int64
        let toUserId: Int64
        let giftType: NFTGift
        let timestamp: Date
        let messageId: Int32?
        
        init(fromUserId: Int64, toUserId: Int64, giftType: NFTGift, messageId: Int32? = nil) {
            self.id = UUID().uuidString
            self.fromUserId = fromUserId
            self.toUserId = toUserId
            self.giftType = giftType
            self.timestamp = Date()
            self.messageId = messageId
        }
    }
    
    private var sentGifts: [GiftRecord] = []
    private var receivedGifts: [GiftRecord] = []
    
    private init() {
        loadData()
    }
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let starBalance = "VirtualStars.balance"
        static let sentGifts = "VirtualStars.sentGifts"
        static let receivedGifts = "VirtualStars.receivedGifts"
    }
    
    // MARK: - Data Persistence
    private func loadData() {
        starBalance = UserDefaults.standard.integer(forKey: Keys.starBalance)
        
        if let sentData = UserDefaults.standard.data(forKey: Keys.sentGifts),
           let sent = try? JSONDecoder().decode([GiftRecord].self, from: sentData) {
            sentGifts = sent
        }
        
        if let receivedData = UserDefaults.standard.data(forKey: Keys.receivedGifts),
           let received = try? JSONDecoder().decode([GiftRecord].self, from: receivedData) {
            receivedGifts = received
        }
    }
    
    private func saveData() {
        UserDefaults.standard.set(starBalance, forKey: Keys.starBalance)
        
        if let sentData = try? JSONEncoder().encode(sentGifts) {
            UserDefaults.standard.set(sentData, forKey: Keys.sentGifts)
        }
        
        if let receivedData = try? JSONEncoder().encode(receivedGifts) {
            UserDefaults.standard.set(receivedData, forKey: Keys.receivedGifts)
        }
        
        NotificationCenter.default.post(name: VirtualStarsManager.balanceChangedNotification, object: nil)
    }
    
    // MARK: - Public API - Stars
    public func getBalance() -> Int {
        return starBalance
    }
    
    public func addStars(_ amount: Int) {
        starBalance += amount
        saveData()
    }
    
    public func purchaseStars(_ amount: Int, completion: @escaping (Bool) -> Void) {
        // Simulate purchase (integrate with real payment system)
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.addStars(amount)
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    // MARK: - Public API - Gifts
    public func canSendGift(_ gift: NFTGift) -> Bool {
        return starBalance >= gift.cost
    }
    
    public func sendGift(_ gift: NFTGift, toUserId: Int64, messageId: Int32? = nil) -> Bool {
        guard canSendGift(gift) else { return false }
        
        starBalance -= gift.cost
        
        let record = GiftRecord(
            fromUserId: 0, // Replace with actual current user ID
            toUserId: toUserId,
            giftType: gift,
            messageId: messageId
        )
        
        sentGifts.append(record)
        saveData()
        
        // Send gift notification to recipient if they use Hakogram
        sendGiftNotification(record)
        
        return true
    }
    
    public func receiveGift(_ gift: NFTGift, fromUserId: Int64, messageId: Int32? = nil) {
        let record = GiftRecord(
            fromUserId: fromUserId,
            toUserId: 0, // Replace with actual current user ID
            giftType: gift,
            messageId: messageId
        )
        
        receivedGifts.append(record)
        saveData()
    }
    
    public func getSentGifts() -> [GiftRecord] {
        return sentGifts.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func getReceivedGifts() -> [GiftRecord] {
        return receivedGifts.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func getGiftsForMessage(_ messageId: Int32) -> [GiftRecord] {
        let sent = sentGifts.filter { $0.messageId == messageId }
        let received = receivedGifts.filter { $0.messageId == messageId }
        return (sent + received).sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Gift Notifications
    private func sendGiftNotification(_ gift: GiftRecord) {
        // Send custom message attribute to recipient
        // This will be visible only to Hakogram users
        NotificationCenter.default.post(
            name: VirtualStarsManager.giftSentNotification,
            object: nil,
            userInfo: ["gift": gift]
        )
    }
    
    // MARK: - Notifications
    public static let balanceChangedNotification = Notification.Name("VirtualStarsBalanceChanged")
    public static let giftSentNotification = Notification.Name("VirtualStarsGiftSent")
    public static let giftReceivedNotification = Notification.Name("VirtualStarsGiftReceived")
}
