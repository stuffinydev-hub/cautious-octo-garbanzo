import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramPresentationData
import ItemListUI
import AccountContext
import AlertUI

public struct JutsoLocalSnapshot: Equatable {
    public let localProfileId: Int64
    public let starsBalance: Int
    public let giftsCount: Int
    public let usersCount: Int
    public let adminUnlocked: Bool
    public let installTimestamp: Double
    public let lastActionTimestamp: Double

    public init(localProfileId: Int64, starsBalance: Int, giftsCount: Int, usersCount: Int, adminUnlocked: Bool, installTimestamp: Double, lastActionTimestamp: Double) {
        self.localProfileId = localProfileId
        self.starsBalance = starsBalance
        self.giftsCount = giftsCount
        self.usersCount = usersCount
        self.adminUnlocked = adminUnlocked
        self.installTimestamp = installTimestamp
        self.lastActionTimestamp = lastActionTimestamp
    }
}

public final class JutsoLocalFeatures {
    public static let shared = JutsoLocalFeatures()

    public enum GiftKind: String, CaseIterable, Codable {
        case visualStars = "visualStars"
        case nftCrystal = "nftCrystal"
        case nftCrown = "nftCrown"
        case nftRocket = "nftRocket"
        case premiumHeart = "premiumHeart"

        public var title: String {
            switch self {
            case .visualStars: return "Визуальные звёзды"
            case .nftCrystal: return "NFT Crystal"
            case .nftCrown: return "NFT Crown"
            case .nftRocket: return "NFT Rocket"
            case .premiumHeart: return "Premium Heart"
            }
        }

        public var emoji: String {
            switch self {
            case .visualStars: return "⭐️"
            case .nftCrystal: return "💎"
            case .nftCrown: return "👑"
            case .nftRocket: return "🚀"
            case .premiumHeart: return "❤️"
            }
        }

        public var cost: Int {
            switch self {
            case .visualStars: return 15
            case .nftCrystal: return 120
            case .nftCrown: return 250
            case .nftRocket: return 350
            case .premiumHeart: return 80
            }
        }
    }

    public struct GiftRecord: Codable {
        public let id: String
        public let direction: String
        public let counterpartId: Int64
        public let counterpartName: String
        public let gift: GiftKind
        public let stars: Int
        public let timestamp: Double
    }

    public struct TrackedUser: Codable {
        public let userId: Int64
        public var displayName: String
        public var username: String?
        public var isBlocked: Bool
        public var createdAt: Double
        public var lastActiveAt: Double
        public var sentGifts: Int
        public var receivedGifts: Int
        public var grantedStars: Int
        public var notes: String
        public var tags: [String]
    }

    public enum FeatureFlag: String, CaseIterable, Codable {
        case giftsEnabled
        case aiEnabled
        case adminToolsEnabled
        case demoNetworkSync
        case maintenanceMode
    }

    public struct ExportBundle: Codable {
        public let version: Int
        public let exportedAt: Double
        public let localProfileId: Int64
        public let installTimestamp: Double
        public let starsBalance: Int
        public let gifts: [GiftRecord]
        public let users: [Int64: TrackedUser]
        public let flags: [FeatureFlag: Bool]
        public let logs: [String]
    }

    private enum Keys {
        static let starsBalance = "Jutso.Local.StarsBalance"
        static let localProfileId = "Jutso.Local.ProfileId"
        static let installTimestamp = "Jutso.Local.InstallTimestamp"
        static let lastActionTimestamp = "Jutso.Local.LastActionTimestamp"
        static let gifts = "Jutso.Local.Gifts"
        static let users = "Jutso.Local.Users"
        static let adminUnlocked = "Jutso.Local.AdminUnlocked"
        static let flags = "Jutso.Local.Flags"
        static let logs = "Jutso.Local.Logs"
        static let aboutLink = "Jutso.Client.AboutLink"
        static let startupPopupEnabled = "Jutso.Client.StartupPopup.Enabled"
        static let startupPopupTitle = "Jutso.Client.StartupPopup.Title"
        static let startupPopupText = "Jutso.Client.StartupPopup.Text"
        static let startupPopupUrl = "Jutso.Client.StartupPopup.Url"
        static let startupPopupEveryNLaunches = "Jutso.Client.StartupPopup.EveryNLaunches"
        static let launchCount = "Jutso.Client.LaunchCount"
        static let maintenanceMessage = "Jutso.Client.MaintenanceMessage"
    }

    private let defaults = UserDefaults.standard
    private let secretCodeValue = "jutsodev-admin"

    private var starsBalance: Int = 250
    private var localProfileId: Int64 = 0
    private var installTimestamp: Double = 0
    private var lastActionTimestamp: Double = 0
    private var gifts: [GiftRecord] = []
    private var users: [Int64: TrackedUser] = [:]
    private var adminUnlocked: Bool = false
    private var flags: [FeatureFlag: Bool] = [
        .giftsEnabled: true,
        .aiEnabled: true,
        .adminToolsEnabled: true,
        .demoNetworkSync: false,
        .maintenanceMode: false
    ]
    private var logs: [String] = []
    private var aboutLink: String = "https://t.me/jutsodev"
    private var startupPopupEnabled: Bool = false
    private var startupPopupTitle: String = "j++gram"
    private var startupPopupText: String = "Добро пожаловать в j++gram."
    private var startupPopupUrl: String = "https://t.me/jutsodev"
    private var startupPopupEveryNLaunches: Int = 1
    private var launchCount: Int = 0
    private var maintenanceMessage: String = "Технические работы. Попробуйте позже."

    private init() {
        self.load()
        self.ensureLocalProfile()
    }

    public func snapshot() -> JutsoLocalSnapshot {
        self.ensureLocalProfile()
        return JutsoLocalSnapshot(
            localProfileId: self.localProfileId,
            starsBalance: self.starsBalance,
            giftsCount: self.gifts.count,
            usersCount: self.users.count,
            adminUnlocked: self.adminUnlocked,
            installTimestamp: self.installTimestamp,
            lastActionTimestamp: self.lastActionTimestamp
        )
    }

    public func isEnabled(_ flag: FeatureFlag) -> Bool {
        return self.flags[flag] ?? false
    }

    public func logEvent(_ name: String, meta: [String: String] = [:]) {
        var meta = meta
        // Hard safety: drop obvious secret keys if a caller makes a mistake.
        for key in ["phone", "code", "otp", "password", "token", "secret", "key"] {
            meta.removeValue(forKey: key)
        }
        if meta.isEmpty {
            self.touch(name)
        } else {
            let tail = meta
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            self.touch("\(name) \(tail)")
        }
        self.save()
    }

    public func setEnabled(_ flag: FeatureFlag, _ value: Bool) {
        self.flags[flag] = value
        self.touch("Set flag \(flag.rawValue)=\(value)")
        self.save()
    }

    public func addStars(_ amount: Int) {
        self.starsBalance += max(0, amount)
        self.touch("Add stars +\(amount)")
        self.save()
    }

    public func setStarsBalance(_ value: Int) {
        self.starsBalance = max(0, value)
        self.touch("Set stars balance=\(value)")
        self.save()
    }

    public func clearGiftHistory() {
        self.gifts.removeAll()
        self.touch("Clear gift history")
        self.save()
    }

    public func clearLogs() {
        self.logs.removeAll()
        self.touch("Clear logs")
        self.save()
    }

    public func resetAll() {
        for key in [Keys.starsBalance, Keys.localProfileId, Keys.installTimestamp, Keys.lastActionTimestamp, Keys.gifts, Keys.users, Keys.adminUnlocked, Keys.flags, Keys.logs] {
            self.defaults.removeObject(forKey: key)
        }
        self.starsBalance = 250
        self.gifts.removeAll()
        self.users.removeAll()
        self.adminUnlocked = false
        self.localProfileId = 0
        self.flags = [
            .giftsEnabled: true,
            .aiEnabled: true,
            .adminToolsEnabled: true,
            .demoNetworkSync: false,
            .maintenanceMode: false
        ]
        self.logs = []
        self.load()
        self.ensureLocalProfile()
        self.touch("Reset all")
        self.save()
    }

    public func unlockAdmin(code: String) -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines)
        self.adminUnlocked = normalized == self.secretCodeValue
        self.touch(self.adminUnlocked ? "Admin unlocked" : "Admin unlock failed")
        self.defaults.set(self.adminUnlocked, forKey: Keys.adminUnlocked)
        return self.adminUnlocked
    }

    public func lockAdmin() {
        self.adminUnlocked = false
        self.touch("Admin locked")
        self.defaults.set(false, forKey: Keys.adminUnlocked)
    }

    public func updateLocalOwner(displayName: String?, username: String?) {
        self.ensureLocalProfile()
        self.upsertUser(userId: self.localProfileId, name: displayName, username: username) { user in
            user.lastActiveAt = Date().timeIntervalSince1970
        }
        self.touch("Update owner profile")
        self.save()
    }

    public func createDemoUser(name: String? = nil) -> TrackedUser {
        self.ensureLocalProfile()
        let id = Int64(100000 + Int.random(in: 100 ... 99999))
        let displayName = (name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Demo User \(Int.random(in: 10 ... 99))"
        self.upsertUser(userId: id, name: displayName, username: nil) { user in
            user.lastActiveAt = Date().timeIntervalSince1970
            user.tags = Array(Set(user.tags + ["demo"]))
        }
        self.touch("Create demo user \(id)")
        self.save()
        return self.users[id]!
    }

    public func listUsers() -> [TrackedUser] {
        return self.users.values.sorted(by: { $0.lastActiveAt > $1.lastActiveAt })
    }

    public func user(byId id: Int64) -> TrackedUser? {
        return self.users[id]
    }

    public func setNotes(userId: Int64, notes: String) {
        guard var user = self.users[userId] else { return }
        user.notes = notes
        user.lastActiveAt = Date().timeIntervalSince1970
        self.users[userId] = user
        self.touch("Set notes for \(userId)")
        self.save()
    }

    public func setTags(userId: Int64, tags: [String]) {
        guard var user = self.users[userId] else { return }
        user.tags = tags
        user.lastActiveAt = Date().timeIntervalSince1970
        self.users[userId] = user
        self.touch("Set tags for \(userId)")
        self.save()
    }

    public func toggleBlocked(userId: Int64) {
        guard userId != self.localProfileId, var user = self.users[userId] else { return }
        user.isBlocked.toggle()
        user.lastActiveAt = Date().timeIntervalSince1970
        self.users[userId] = user
        self.touch("\(user.isBlocked ? "Block" : "Unblock") \(userId)")
        self.save()
    }

    public func grantStarsToUser(userId: Int64, amount: Int) {
        self.ensureLocalProfile()
        if userId == self.localProfileId {
            self.addStars(amount)
            return
        }
        self.upsertUser(userId: userId, name: nil, username: nil) { user in
            user.grantedStars += max(0, amount)
            user.lastActiveAt = Date().timeIntervalSince1970
        }
        self.touch("Grant stars \(amount) to \(userId)")
        self.save()
    }

    public func sendGift(to userId: Int64, name: String, gift: GiftKind) -> Bool {
        self.ensureLocalProfile()
        guard self.isEnabled(.giftsEnabled), !self.isUserBlocked(userId), self.starsBalance >= gift.cost else {
            self.touch("Send gift failed to \(userId)")
            return false
        }
        self.starsBalance -= gift.cost
        let cleanName = self.normalizedName(name, fallbackId: userId)
        let timestamp = Date().timeIntervalSince1970
        self.gifts.insert(GiftRecord(id: UUID().uuidString, direction: "outgoing", counterpartId: userId, counterpartName: cleanName, gift: gift, stars: gift.cost, timestamp: timestamp), at: 0)
        self.upsertUser(userId: userId, name: cleanName, username: nil) { user in
            user.sentGifts += 1
            user.lastActiveAt = timestamp
        }
        self.touch("Send gift \(gift.rawValue) -> \(userId)")
        self.save()
        return true
    }

    public func simulateIncomingGift(from userId: Int64, name: String, gift: GiftKind) {
        self.ensureLocalProfile()
        guard self.isEnabled(.giftsEnabled) else {
            self.touch("Receive gift ignored (disabled)")
            return
        }
        let cleanName = self.normalizedName(name, fallbackId: userId)
        let timestamp = Date().timeIntervalSince1970
        self.gifts.insert(GiftRecord(id: UUID().uuidString, direction: "incoming", counterpartId: userId, counterpartName: cleanName, gift: gift, stars: gift.cost, timestamp: timestamp), at: 0)
        self.upsertUser(userId: userId, name: cleanName, username: nil) { user in
            user.receivedGifts += 1
            user.lastActiveAt = timestamp
        }
        self.touch("Receive gift \(gift.rawValue) <- \(userId)")
        self.save()
    }

    public func listGifts(limit: Int = 50) -> [GiftRecord] {
        return Array(self.gifts.sorted(by: { $0.timestamp > $1.timestamp }).prefix(max(0, limit)))
    }

    public func exportBundle() -> ExportBundle {
        return ExportBundle(
            version: 1,
            exportedAt: Date().timeIntervalSince1970,
            localProfileId: self.localProfileId,
            installTimestamp: self.installTimestamp,
            starsBalance: self.starsBalance,
            gifts: self.gifts,
            users: self.users,
            flags: self.flags,
            logs: self.logs
        )
    }

    public func importBundle(_ bundle: ExportBundle) {
        self.starsBalance = max(0, bundle.starsBalance)
        self.localProfileId = bundle.localProfileId
        self.installTimestamp = bundle.installTimestamp
        self.gifts = bundle.gifts
        self.users = bundle.users
        self.flags = bundle.flags
        self.logs = bundle.logs
        self.touch("Import bundle v\(bundle.version)")
        self.save()
    }

    public func secretCodeHint() -> String {
        return self.secretCodeValue
    }

    public func getAboutLink() -> String {
        return self.aboutLink
    }

    public func setAboutLink(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.aboutLink = trimmed.isEmpty ? "https://t.me/jutsodev" : trimmed
        self.touch("Client.AboutLinkUpdated")
        self.save()
    }

    public struct StartupPopupConfig: Equatable {
        public var enabled: Bool
        public var title: String
        public var text: String
        public var url: String
        public var everyNLaunches: Int
    }

    public func getStartupPopup() -> StartupPopupConfig {
        return StartupPopupConfig(
            enabled: self.startupPopupEnabled,
            title: self.startupPopupTitle,
            text: self.startupPopupText,
            url: self.startupPopupUrl,
            everyNLaunches: max(1, self.startupPopupEveryNLaunches)
        )
    }

    public func setStartupPopup(_ config: StartupPopupConfig) {
        self.startupPopupEnabled = config.enabled
        self.startupPopupTitle = config.title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.startupPopupText = config.text.trimmingCharacters(in: .whitespacesAndNewlines)
        self.startupPopupUrl = config.url.trimmingCharacters(in: .whitespacesAndNewlines)
        self.startupPopupEveryNLaunches = max(1, config.everyNLaunches)
        self.touch("Client.StartupPopupUpdated enabled=\(config.enabled) every=\(self.startupPopupEveryNLaunches)")
        self.save()
    }

    public func getMaintenanceMessage() -> String {
        return self.maintenanceMessage
    }

    public func setMaintenanceMessage(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.maintenanceMessage = trimmed.isEmpty ? "Технические работы. Попробуйте позже." : trimmed
        self.touch("Client.MaintenanceMessageUpdated")
        self.save()
    }

    public func registerLaunchAndShouldShowStartupPopup() -> Bool {
        self.launchCount += 1
        self.touch("App.Launched #\(self.launchCount)")
        self.save()
        guard self.startupPopupEnabled else {
            return false
        }
        let every = max(1, self.startupPopupEveryNLaunches)
        return (self.launchCount % every) == 0
    }

    public func isUserBlocked(_ userId: Int64) -> Bool {
        return self.users[userId]?.isBlocked ?? false
    }

    private func touch(_ message: String) {
        self.lastActionTimestamp = Date().timeIntervalSince1970
        let ts = DateFormatter.localizedString(from: Date(timeIntervalSince1970: self.lastActionTimestamp), dateStyle: .short, timeStyle: .medium)
        self.logs.append("[\(ts)] \(message)")
        if self.logs.count > 1200 {
            self.logs = Array(self.logs.suffix(1200))
        }
    }

    private func load() {
        let storedStars = self.defaults.object(forKey: Keys.starsBalance) as? Int
        self.starsBalance = storedStars ?? 250
        self.localProfileId = self.defaults.object(forKey: Keys.localProfileId) as? Int64 ?? 0
        self.installTimestamp = self.defaults.object(forKey: Keys.installTimestamp) as? Double ?? 0
        self.lastActionTimestamp = self.defaults.object(forKey: Keys.lastActionTimestamp) as? Double ?? 0
        self.adminUnlocked = self.defaults.bool(forKey: Keys.adminUnlocked)

        if let data = self.defaults.data(forKey: Keys.gifts), let gifts = try? JSONDecoder().decode([GiftRecord].self, from: data) {
            self.gifts = gifts
        }
        if let data = self.defaults.data(forKey: Keys.users), let users = try? JSONDecoder().decode([Int64: TrackedUser].self, from: data) {
            self.users = users
        }
        if let data = self.defaults.data(forKey: Keys.flags), let flags = try? JSONDecoder().decode([FeatureFlag: Bool].self, from: data) {
            self.flags = flags
        }
        if let data = self.defaults.data(forKey: Keys.logs), let logs = try? JSONDecoder().decode([String].self, from: data) {
            self.logs = logs
        }

        self.aboutLink = (self.defaults.string(forKey: Keys.aboutLink) ?? self.aboutLink)
        self.startupPopupEnabled = self.defaults.bool(forKey: Keys.startupPopupEnabled)
        self.startupPopupTitle = self.defaults.string(forKey: Keys.startupPopupTitle) ?? self.startupPopupTitle
        self.startupPopupText = self.defaults.string(forKey: Keys.startupPopupText) ?? self.startupPopupText
        self.startupPopupUrl = self.defaults.string(forKey: Keys.startupPopupUrl) ?? self.startupPopupUrl
        self.startupPopupEveryNLaunches = self.defaults.object(forKey: Keys.startupPopupEveryNLaunches) as? Int ?? self.startupPopupEveryNLaunches
        self.launchCount = self.defaults.object(forKey: Keys.launchCount) as? Int ?? self.launchCount
        self.maintenanceMessage = self.defaults.string(forKey: Keys.maintenanceMessage) ?? self.maintenanceMessage

        if self.installTimestamp <= 0 {
            self.installTimestamp = Date().timeIntervalSince1970
        }
        if self.lastActionTimestamp <= 0 {
            self.lastActionTimestamp = self.installTimestamp
        }
    }

    private func save() {
        self.defaults.set(self.starsBalance, forKey: Keys.starsBalance)
        self.defaults.set(self.localProfileId, forKey: Keys.localProfileId)
        self.defaults.set(self.installTimestamp, forKey: Keys.installTimestamp)
        self.defaults.set(self.lastActionTimestamp, forKey: Keys.lastActionTimestamp)
        self.defaults.set(self.adminUnlocked, forKey: Keys.adminUnlocked)
        if let data = try? JSONEncoder().encode(self.gifts) {
            self.defaults.set(data, forKey: Keys.gifts)
        }
        if let data = try? JSONEncoder().encode(self.users) {
            self.defaults.set(data, forKey: Keys.users)
        }
        if let data = try? JSONEncoder().encode(self.flags) {
            self.defaults.set(data, forKey: Keys.flags)
        }
        if let data = try? JSONEncoder().encode(self.logs) {
            self.defaults.set(data, forKey: Keys.logs)
        }
        self.defaults.set(self.aboutLink, forKey: Keys.aboutLink)
        self.defaults.set(self.startupPopupEnabled, forKey: Keys.startupPopupEnabled)
        self.defaults.set(self.startupPopupTitle, forKey: Keys.startupPopupTitle)
        self.defaults.set(self.startupPopupText, forKey: Keys.startupPopupText)
        self.defaults.set(self.startupPopupUrl, forKey: Keys.startupPopupUrl)
        self.defaults.set(self.startupPopupEveryNLaunches, forKey: Keys.startupPopupEveryNLaunches)
        self.defaults.set(self.launchCount, forKey: Keys.launchCount)
        self.defaults.set(self.maintenanceMessage, forKey: Keys.maintenanceMessage)
    }

    private func ensureLocalProfile() {
        if self.localProfileId == 0 {
            self.localProfileId = Int64(700000 + Int.random(in: 1000 ... 999999))
        }
        self.upsertUser(userId: self.localProfileId, name: "Jutso Owner", username: nil) { user in
            user.lastActiveAt = Date().timeIntervalSince1970
            user.tags = Array(Set(user.tags + ["owner"]))
        }
        self.save()
    }

    private func upsertUser(userId: Int64, name: String?, username: String?, update: (inout TrackedUser) -> Void) {
        let now = Date().timeIntervalSince1970
        var user = self.users[userId] ?? TrackedUser(
            userId: userId,
            displayName: self.normalizedName(name, fallbackId: userId),
            username: username,
            isBlocked: false,
            createdAt: now,
            lastActiveAt: now,
            sentGifts: 0,
            receivedGifts: 0,
            grantedStars: 0,
            notes: "",
            tags: []
        )
        if let name, !name.isEmpty { user.displayName = name }
        if let username { user.username = username }
        update(&user)
        self.users[userId] = user
    }

    private func normalizedName(_ value: String?, fallbackId: Int64) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "User \(fallbackId)" : trimmed
    }
}

private func dateString(_ ts: Double) -> String {
    return DateFormatter.localizedString(from: Date(timeIntervalSince1970: ts), dateStyle: .short, timeStyle: .short)
}

private enum JutsoStarsSection: Int32 {
    case overview
    case recipient
    case actions
    case history
}

private struct JutsoStarsState: Equatable {
    var recipientId: String
    var recipientName: String
    var selectedGift: JutsoLocalFeatures.GiftKind
    static func initial() -> JutsoStarsState {
        return JutsoStarsState(recipientId: "", recipientName: "", selectedGift: .visualStars)
    }
}

private enum JutsoStarsEntry: ItemListNodeEntry {
    case overview(PresentationTheme, String)
    case recipientId(PresentationTheme, String)
    case recipientName(PresentationTheme, String)
    case gift(PresentationTheme, String, String)
    case send(PresentationTheme, String, Bool)
    case receive(PresentationTheme, String, Bool)
    case addStars(PresentationTheme, String)
    case clearHistory(PresentationTheme, String, Bool)
    case history(Int32, PresentationTheme, String)
    case info(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .overview: return JutsoStarsSection.overview.rawValue
        case .recipientId, .recipientName, .gift: return JutsoStarsSection.recipient.rawValue
        case .send, .receive, .addStars, .clearHistory: return JutsoStarsSection.actions.rawValue
        case .history, .info: return JutsoStarsSection.history.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .overview: return 0
        case .recipientId: return 1
        case .recipientName: return 2
        case .gift: return 3
        case .send: return 4
        case .receive: return 5
        case .addStars: return 6
        case .clearHistory: return 7
        case let .history(index, _, _): return 100 + index
        case .info: return 1000
        }
    }

    static func ==(lhs: JutsoStarsEntry, rhs: JutsoStarsEntry) -> Bool {
        switch lhs {
        case let .overview(lt, ls):
            if case let .overview(rt, rs) = rhs { return lt === rt && ls == rs }
            return false
        case let .recipientId(lt, ls):
            if case let .recipientId(rt, rs) = rhs { return lt === rt && ls == rs }
            return false
        case let .recipientName(lt, ls):
            if case let .recipientName(rt, rs) = rhs { return lt === rt && ls == rs }
            return false
        case let .gift(lt, ltit, lval):
            if case let .gift(rt, rtit, rval) = rhs { return lt === rt && ltit == rtit && lval == rval }
            return false
        case let .send(lt, ls, le):
            if case let .send(rt, rs, re) = rhs { return lt === rt && ls == rs && le == re }
            return false
        case let .receive(lt, ls, le):
            if case let .receive(rt, rs, re) = rhs { return lt === rt && ls == rs && le == re }
            return false
        case let .addStars(lt, ls):
            if case let .addStars(rt, rs) = rhs { return lt === rt && ls == rs }
            return false
        case let .clearHistory(lt, ls, le):
            if case let .clearHistory(rt, rs, re) = rhs { return lt === rt && ls == rs && le == re }
            return false
        case let .history(li, lt, ls):
            if case let .history(ri, rt, rs) = rhs { return li == ri && lt === rt && ls == rs }
            return false
        case let .info(lt, ls):
            if case let .info(rt, rs) = rhs { return lt === rt && ls == rs }
            return false
        }
    }

    static func <(lhs: JutsoStarsEntry, rhs: JutsoStarsEntry) -> Bool {
        lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! JutsoStarsArguments
        switch self {
        case let .overview(_, text), let .history(_, _, text), let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .recipientId(theme, value):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(string: "ID", textColor: theme.list.itemPrimaryTextColor),
                text: value,
                placeholder: "Введите ID пользователя",
                type: .number,
                sectionId: self.section,
                textUpdated: { arguments.updateRecipientId($0) },
                action: {}
            )
        case let .recipientName(_, value):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(),
                text: value,
                placeholder: "Имя получателя",
                type: .regular(capitalization: true, autocorrection: false),
                clearType: .always,
                sectionId: self.section,
                textUpdated: { arguments.updateRecipientName($0) },
                action: {}
            )
        case let .gift(_, title, value):
            return ItemListDisclosureItem(
                presentationData: presentationData,
                title: title,
                label: value,
                sectionId: self.section,
                style: .blocks,
                action: { arguments.openGiftPicker() }
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
                action: { if enabled { arguments.sendGift() } }
            )
        case let .receive(_, title, enabled):
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                kind: enabled ? .generic : .disabled,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: { if enabled { arguments.simulateIncomingGift() } }
            )
        case let .addStars(_, title):
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: title,
                kind: .generic,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: { arguments.addDemoStars() }
            )
        case let .clearHistory(_, title, enabled):
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

private final class JutsoStarsArguments {
    let updateRecipientId: (String) -> Void
    let updateRecipientName: (String) -> Void
    let openGiftPicker: () -> Void
    let sendGift: () -> Void
    let simulateIncomingGift: () -> Void
    let addDemoStars: () -> Void
    let clearHistory: () -> Void

    init(updateRecipientId: @escaping (String) -> Void, updateRecipientName: @escaping (String) -> Void, openGiftPicker: @escaping () -> Void, sendGift: @escaping () -> Void, simulateIncomingGift: @escaping () -> Void, addDemoStars: @escaping () -> Void, clearHistory: @escaping () -> Void) {
        self.updateRecipientId = updateRecipientId
        self.updateRecipientName = updateRecipientName
        self.openGiftPicker = openGiftPicker
        self.sendGift = sendGift
        self.simulateIncomingGift = simulateIncomingGift
        self.addDemoStars = addDemoStars
        self.clearHistory = clearHistory
    }
}

private func giftLine(_ gift: JutsoLocalFeatures.GiftRecord) -> String {
    let action = gift.direction == "incoming" ? "Получено" : "Отправлено"
    return "\(gift.gift.emoji) \(action): \(gift.counterpartName) • \(gift.gift.title) • \(gift.stars)⭐️\n\(dateString(gift.timestamp))"
}

private func starsEntries(presentationData: PresentationData, state: JutsoStarsState) -> [JutsoStarsEntry] {
    let snapshot = JutsoLocalFeatures.shared.snapshot()
    var entries: [JutsoStarsEntry] = []

    let header = "Профиль клиента: \(snapshot.localProfileId)\nУстановлено: \(dateString(snapshot.installTimestamp))\nБаланс: \(snapshot.starsBalance)⭐️\nПодарков: \(snapshot.giftsCount) • Пользователей: \(snapshot.usersCount)"
    entries.append(.overview(presentationData.theme, header))
    entries.append(.recipientId(presentationData.theme, state.recipientId))
    entries.append(.recipientName(presentationData.theme, state.recipientName))
    entries.append(.gift(presentationData.theme, "Подарок", "\(state.selectedGift.emoji) \(state.selectedGift.title) • \(state.selectedGift.cost)⭐️"))

    let canAct = !state.recipientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    entries.append(.send(presentationData.theme, "Подарить локально", canAct && JutsoLocalFeatures.shared.isEnabled(.giftsEnabled)))
    entries.append(.receive(presentationData.theme, "Симулировать входящий подарок", canAct && JutsoLocalFeatures.shared.isEnabled(.giftsEnabled)))
    entries.append(.addStars(presentationData.theme, "Накрутить +250⭐️"))
    entries.append(.clearHistory(presentationData.theme, "Очистить историю подарков", snapshot.giftsCount > 0))

    let gifts = JutsoLocalFeatures.shared.listGifts(limit: 10)
    if gifts.isEmpty {
        entries.append(.info(presentationData.theme, "Подарки и NFT‑подарки — локальные. Можно имитировать обмен между пользователями клиента, вводя одинаковые ID."))
    } else {
        for (index, gift) in gifts.enumerated() {
            entries.append(.history(Int32(index), presentationData.theme, giftLine(gift)))
        }
        entries.append(.info(presentationData.theme, "Подсказка: в админ‑панели можно экспортировать/импортировать локальную базу, чтобы переносить демо‑историю."))
    }

    return entries
}

public func jutsoStarsController(context: AccountContext) -> ViewController {
    var presentImpl: ((ViewController) -> Void)?

    let stateValue = Atomic(value: JutsoStarsState.initial())
    let statePromise = ValuePromise(JutsoStarsState.initial(), ignoreRepeated: false)

    func updateState(_ f: (inout JutsoStarsState) -> Void) {
        let updated = stateValue.modify { current in
            var current = current
            f(&current)
            return current
        }
        statePromise.set(updated)
    }

    func showMessage(_ text: String) {
        let controller = textAlertController(context: context, updatedPresentationData: nil, title: "Jutso Gifts", text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})])
        presentImpl?(controller)
    }

    let arguments = JutsoStarsArguments(
        updateRecipientId: { updateState { $0.recipientId = $0 } },
        updateRecipientName: { updateState { $0.recipientName = $0 } },
        openGiftPicker: {
            let actions: [TextAlertAction] = JutsoLocalFeatures.GiftKind.allCases.map { gift in
                TextAlertAction(type: .genericAction, title: "\(gift.emoji) \(gift.title) • \(gift.cost)⭐️", action: {
                    updateState { $0.selectedGift = gift }
                })
            } + [TextAlertAction(type: .genericAction, title: "Отмена", action: {})]
            presentImpl?(textAlertController(context: context, updatedPresentationData: nil, title: "Выберите подарок", text: "Локальные визуальные звёзды и NFT‑подарки.", actions: actions))
        },
        sendGift: {
            let state = stateValue.with { $0 }
            guard let userId = Int64(state.recipientId.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                showMessage("Введите корректный ID получателя.")
                return
            }
            if JutsoLocalFeatures.shared.sendGift(to: userId, name: state.recipientName, gift: state.selectedGift) {
                showMessage("Подарок отправлен локально и отображается в истории.")
                statePromise.set(stateValue.with { $0 })
            } else {
                showMessage("Не удалось отправить подарок. Проверьте баланс, блокировку или флаг GiftsEnabled.")
            }
        },
        simulateIncomingGift: {
            let state = stateValue.with { $0 }
            guard let userId = Int64(state.recipientId.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                showMessage("Введите корректный ID отправителя.")
                return
            }
            JutsoLocalFeatures.shared.simulateIncomingGift(from: userId, name: state.recipientName, gift: state.selectedGift)
            showMessage("Входящий подарок добавлен локально.")
            statePromise.set(stateValue.with { $0 })
        },
        addDemoStars: {
            JutsoLocalFeatures.shared.addStars(250)
            showMessage("Добавлено +250⭐️ локально.")
            statePromise.set(stateValue.with { $0 })
        },
        clearHistory: {
            JutsoLocalFeatures.shared.clearGiftHistory()
            showMessage("История подарков очищена.")
            statePromise.set(stateValue.with { $0 })
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Jutso Gifts"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        let listState = ItemListNodeState(
            presentationData: ItemListPresentationData(presentationData),
            entries: starsEntries(presentationData: presentationData, state: state),
            style: .blocks,
            animateChanges: true
        )
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.didAppear = { _ in
        statePromise.set(stateValue.with { $0 })
    }
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Admin

private enum JutsoAdminSection: Int32 {
    case access
    case dashboard
    case toggles
    case users
    case tools
    case logs
}

private struct JutsoAdminAccessState: Equatable {
    var code: String = ""
}

private struct JutsoAdminPanelState: Equatable {
    var searchId: String = ""
    var grantId: String = ""
    var grantAmount: String = "100"
    var setBalance: String = ""
    var aboutLink: String = ""
    var popupTitle: String = ""
    var popupText: String = ""
    var popupUrl: String = ""
    var popupEvery: String = "1"
    var maintenanceMessage: String = ""
    var aiKeyInput: String = ""
}

private enum JutsoAdminAccessEntry: ItemListNodeEntry {
    case code(PresentationTheme, String)
    case open(PresentationTheme, Bool)
    case info(PresentationTheme, String)

    var section: ItemListSectionId { JutsoAdminSection.access.rawValue }
    var stableId: Int32 {
        switch self { case .code: return 0; case .open: return 1; case .info: return 2 }
    }
    static func ==(lhs: JutsoAdminAccessEntry, rhs: JutsoAdminAccessEntry) -> Bool {
        switch lhs {
        case let .code(lt, lv): if case let .code(rt, rv) = rhs { return lt === rt && lv == rv }; return false
        case let .open(lt, lv): if case let .open(rt, rv) = rhs { return lt === rt && lv == rv }; return false
        case let .info(lt, lv): if case let .info(rt, rv) = rhs { return lt === rt && lv == rv }; return false
        }
    }
    static func <(lhs: JutsoAdminAccessEntry, rhs: JutsoAdminAccessEntry) -> Bool { lhs.stableId < rhs.stableId }
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! JutsoAdminAccessArguments
        switch self {
        case let .code(theme, value):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(string: "Код", textColor: theme.list.itemPrimaryTextColor),
                text: value,
                placeholder: "Секретный код",
                type: .password,
                clearType: .always,
                sectionId: self.section,
                textUpdated: { args.updateCode($0) },
                action: { args.openPanel() }
            )
        case let .open(_, unlocked):
            return ItemListActionItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: unlocked ? "Открыть админ‑панель" : "Разблокировать",
                kind: .generic,
                alignment: .natural,
                sectionId: self.section,
                style: .blocks,
                action: { args.openPanel() }
            )
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private final class JutsoAdminAccessArguments {
    let updateCode: (String) -> Void
    let openPanel: () -> Void
    init(updateCode: @escaping (String) -> Void, openPanel: @escaping () -> Void) { self.updateCode = updateCode; self.openPanel = openPanel }
}

public func jutsoAdminAccessController(context: AccountContext) -> ViewController {
    var pushImpl: ((ViewController, Bool) -> Void)?
    var presentImpl: ((ViewController) -> Void)?

    let stateValue = Atomic(value: JutsoAdminAccessState())
    let statePromise = ValuePromise(JutsoAdminAccessState(), ignoreRepeated: true)

    func updateState(_ f: (inout JutsoAdminAccessState) -> Void) {
        let updated = stateValue.modify { current in
            var current = current
            f(&current)
            return current
        }
        statePromise.set(updated)
    }

    let arguments = JutsoAdminAccessArguments(
        updateCode: { value in updateState { $0.code = value } },
        openPanel: {
            let code = stateValue.with { $0.code }
            if JutsoLocalFeatures.shared.snapshot().adminUnlocked || JutsoLocalFeatures.shared.unlockAdmin(code: code) {
                pushImpl?(jutsoAdminPanelController(context: context), true)
            } else {
                presentImpl?(textAlertController(context: context, updatedPresentationData: nil, title: "Доступ запрещён", text: "Код неверный.", actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]))
            }
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get())
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let unlocked = JutsoLocalFeatures.shared.snapshot().adminUnlocked
        let entries: [JutsoAdminAccessEntry] = [
            .code(presentationData.theme, state.code),
            .open(presentationData.theme, unlocked),
            .info(presentationData.theme, "Админка локальная и открывается только по секретному коду.")
        ]
        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("Admin Access"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushImpl = { [weak controller] c, animated in controller?.push(c) }
    presentImpl = { [weak controller] c in controller?.present(c, in: .window(.root)) }
    return controller
}

private enum JutsoAdminPanelEntry: ItemListNodeEntry {
    case dashboard(PresentationTheme, String)
    case toggle(Int32, PresentationTheme, String, String)
    case input(Int32, PresentationTheme, String, String, String, ItemListSingleLineInputItemType)
    case action(Int32, PresentationTheme, String)
    case user(Int32, PresentationTheme, String, String)
    case log(Int32, PresentationTheme, String)
    case info(PresentationTheme, String)

    var section: ItemListSectionId {
        switch self {
        case .dashboard: return JutsoAdminSection.dashboard.rawValue
        case .toggle: return JutsoAdminSection.toggles.rawValue
        case .input, .action: return JutsoAdminSection.tools.rawValue
        case .user: return JutsoAdminSection.users.rawValue
        case .log, .info: return JutsoAdminSection.logs.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .dashboard: return 0
        case let .toggle(id, _, _, _): return 100 + id
        case let .input(id, _, _, _, _, _): return 200 + id
        case let .action(id, _, _): return 300 + id
        case let .user(id, _, _, _): return 400 + id
        case let .log(id, _, _): return 500 + id
        case .info: return 9999
        }
    }

    static func ==(lhs: JutsoAdminPanelEntry, rhs: JutsoAdminPanelEntry) -> Bool {
        switch lhs {
        case let .dashboard(lt, ls):
            if case let .dashboard(rt, rs) = rhs { return lt === rt && ls == rs }; return false
        case let .toggle(li, lt, la, lv):
            if case let .toggle(ri, rt, ra, rv) = rhs { return li == ri && lt === rt && la == ra && lv == rv }; return false
        case let .input(li, lt, ltitle, ltext, lph, ltype):
            if case let .input(ri, rt, rtitle, rtext, rph, rtype) = rhs { return li == ri && lt === rt && ltitle == rtitle && ltext == rtext && lph == rph && ltype == rtype }; return false
        case let .action(li, lt, ls):
            if case let .action(ri, rt, rs) = rhs { return li == ri && lt === rt && ls == rs }; return false
        case let .user(li, lt, ls, lv):
            if case let .user(ri, rt, rs, rv) = rhs { return li == ri && lt === rt && ls == rs && lv == rv }; return false
        case let .log(li, lt, ls):
            if case let .log(ri, rt, rs) = rhs { return li == ri && lt === rt && ls == rs }; return false
        case let .info(lt, ls):
            if case let .info(rt, rs) = rhs { return lt === rt && ls == rs }; return false
        }
    }

    static func <(lhs: JutsoAdminPanelEntry, rhs: JutsoAdminPanelEntry) -> Bool { lhs.stableId < rhs.stableId }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let args = arguments as! JutsoAdminPanelArguments
        switch self {
        case let .dashboard(_, text), let .info(_, text), let .log(_, _, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .toggle(id, _, title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: { args.toggle(id) })
        case let .input(_, theme, title, text, placeholder, type):
            return ItemListSingleLineInputItem(
                presentationData: presentationData,
                systemStyle: .glass,
                title: NSAttributedString(string: title, textColor: theme.list.itemPrimaryTextColor),
                text: text,
                placeholder: placeholder,
                type: type,
                clearType: .always,
                sectionId: self.section,
                textUpdated: { args.updateInput(title, $0) },
                action: {}
            )
        case let .action(id, _, title):
            return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: { args.action(id) })
        case let .user(id, _, title, value):
            return ItemListDisclosureItem(presentationData: presentationData, title: title, label: value, sectionId: self.section, style: .blocks, action: { args.openUser(id) })
        }
    }
}

private final class JutsoAdminPanelArguments {
    let updateInput: (String, String) -> Void
    let toggle: (Int32) -> Void
    let action: (Int32) -> Void
    let openUser: (Int32) -> Void
    init(updateInput: @escaping (String, String) -> Void, toggle: @escaping (Int32) -> Void, action: @escaping (Int32) -> Void, openUser: @escaping (Int32) -> Void) {
        self.updateInput = updateInput
        self.toggle = toggle
        self.action = action
        self.openUser = openUser
    }
}

private func userLabel(_ user: JutsoLocalFeatures.TrackedUser) -> String {
    let status = user.isBlocked ? "blocked" : "ok"
    let uname = user.username.flatMap { $0.isEmpty ? nil : "@\($0)" } ?? ""
    return "\(status) • \(uname) • gifts \(user.sentGifts)/\(user.receivedGifts)"
}

public func jutsoAdminPanelController(context: AccountContext) -> ViewController {
    var presentImpl: ((ViewController) -> Void)?
    let refreshToken = ValuePromise(0, ignoreRepeated: false)

    let stateValue = Atomic(value: JutsoAdminPanelState())
    let statePromise = ValuePromise(JutsoAdminPanelState(), ignoreRepeated: false)

    func updateState(_ f: (inout JutsoAdminPanelState) -> Void) {
        let updated = stateValue.modify { current in
            var current = current
            f(&current)
            return current
        }
        statePromise.set(updated)
    }

    func refresh() {
        refreshToken.set(Int.random(in: 0 ... Int.max))
    }

    func alert(_ title: String, _ text: String) {
        presentImpl?(textAlertController(context: context, updatedPresentationData: nil, title: title, text: text, actions: [TextAlertAction(type: .defaultAction, title: "OK", action: {})]))
    }

    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        alert("Скопировано", "Данные скопированы в буфер обмена.")
    }

    let arguments = JutsoAdminPanelArguments(
        updateInput: { key, value in
            updateState { state in
                switch key {
                case "SearchID":
                    state.searchId = value
                case "GrantID":
                    state.grantId = value
                case "GrantAmount":
                    state.grantAmount = value
                case "SetBalance":
                    state.setBalance = value
                case "AboutLink":
                    state.aboutLink = value
                case "PopupTitle":
                    state.popupTitle = value
                case "PopupText":
                    state.popupText = value
                case "PopupUrl":
                    state.popupUrl = value
                case "PopupEvery":
                    state.popupEvery = value
                case "MaintenanceMessage":
                    state.maintenanceMessage = value
                case "AIKey":
                    state.aiKeyInput = value
                default:
                    break
                }
            }
        },
        toggle: { toggleId in
            let map: [(Int32, JutsoLocalFeatures.FeatureFlag, String)] = [
                (0, .giftsEnabled, "GiftsEnabled"),
                (1, .aiEnabled, "AIEnabled"),
                (2, .adminToolsEnabled, "AdminToolsEnabled"),
                (3, .demoNetworkSync, "DemoNetworkSync"),
                (4, .maintenanceMode, "MaintenanceMode")
            ]
            if let flag = map.first(where: { $0.0 == toggleId })?.1 {
                JutsoLocalFeatures.shared.setEnabled(flag, !JutsoLocalFeatures.shared.isEnabled(flag))
                refresh()
                return
            }
            if toggleId == 20 {
                let current = JutsoLocalFeatures.shared.getStartupPopup()
                JutsoLocalFeatures.shared.setStartupPopup(.init(
                    enabled: !current.enabled,
                    title: current.title,
                    text: current.text,
                    url: current.url,
                    everyNLaunches: current.everyNLaunches
                ))
                refresh()
                return
            }
        },
        action: { actionId in
            switch actionId {
            case 0:
                JutsoLocalFeatures.shared.addStars(500)
                alert("Готово", "Начислено +500⭐️ владельцу локально.")
            case 1:
                let user = JutsoLocalFeatures.shared.createDemoUser()
                alert("Demo", "Создан demo‑пользователь:\n\(user.displayName)\nID: \(user.userId)")
            case 2:
                JutsoLocalFeatures.shared.clearGiftHistory()
                alert("Очищено", "История подарков очищена.")
            case 3:
                JutsoLocalFeatures.shared.clearLogs()
                alert("Очищено", "Логи очищены.")
            case 4:
                let bundle = JutsoLocalFeatures.shared.exportBundle()
                if let data = try? JSONEncoder().encode(bundle), let json = String(data: data, encoding: .utf8) {
                    copyToClipboard(json)
                } else {
                    alert("Ошибка", "Не удалось сформировать экспорт.")
                }
            case 5:
                guard let text = UIPasteboard.general.string, let data = text.data(using: .utf8), let bundle = try? JSONDecoder().decode(JutsoLocalFeatures.ExportBundle.self, from: data) else {
                    alert("Ошибка", "В буфере обмена нет корректного JSON экспорта.")
                    return
                }
                JutsoLocalFeatures.shared.importBundle(bundle)
                alert("Импорт", "Импорт выполнен. Данные обновлены.")
            case 6:
                let st = stateValue.with { $0 }
                if let balance = Int(st.setBalance.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    JutsoLocalFeatures.shared.setStarsBalance(balance)
                    alert("Готово", "Баланс установлен: \(balance)⭐️")
                } else {
                    alert("Ошибка", "Введите корректное число для баланса.")
                }
            case 7:
                let st = stateValue.with { $0 }
                guard let uid = Int64(st.grantId.trimmingCharacters(in: .whitespacesAndNewlines)), let amount = Int(st.grantAmount.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    alert("Ошибка", "Введите корректный ID и сумму.")
                    return
                }
                JutsoLocalFeatures.shared.grantStarsToUser(userId: uid, amount: amount)
                alert("Готово", "Выдано \(amount)⭐️ пользователю \(uid).")
            case 8:
                JutsoLocalFeatures.shared.lockAdmin()
                alert("Выход", "Админ‑панель заблокирована.")
            case 9:
                JutsoLocalFeatures.shared.resetAll()
                alert("Сброс", "Локальная база сброшена.")
            case 10:
                let st = stateValue.with { $0 }
                JutsoLocalFeatures.shared.setAboutLink(st.aboutLink)
                alert("Готово", "Ссылка About обновлена.")
            case 11:
                let st = stateValue.with { $0 }
                let every = Int(st.popupEvery.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
                let enabled = JutsoLocalFeatures.shared.getStartupPopup().enabled
                JutsoLocalFeatures.shared.setStartupPopup(.init(
                    enabled: enabled,
                    title: st.popupTitle,
                    text: st.popupText,
                    url: st.popupUrl,
                    everyNLaunches: every
                ))
                alert("Готово", "Startup popup обновлён.")
            case 12:
                let cfg = JutsoLocalFeatures.shared.getStartupPopup()
                UIPasteboard.general.string = cfg.url
                alert(cfg.title.isEmpty ? "j++gram" : cfg.title, cfg.text.isEmpty ? "Startup popup" : cfg.text)
            case 13:
                let key = stateValue.with { $0.aiKeyInput }
                if JppgramAIKeyStore.setKey(key) {
                    alert("Готово", "AI ключ сохранён в Keychain.")
                } else {
                    alert("Ошибка", "Введите непустой AI ключ.")
                }
            case 14:
                _ = JppgramAIKeyStore.clear()
                alert("Готово", "AI ключ удалён из Keychain.")
            case 15:
                let st = stateValue.with { $0 }
                JutsoLocalFeatures.shared.setMaintenanceMessage(st.maintenanceMessage)
                alert("Готово", "Maintenance message обновлено.")
            default:
                break
            }
            refresh()
        },
        openUser: { index in
            let users = JutsoLocalFeatures.shared.listUsers()
            guard index >= 0 && index < Int32(users.count) else { return }
            let user = users[Int(index)]
            let blockedTitle = user.isBlocked ? "Разблокировать" : "Заблокировать"
            let details = "ID: \(user.userId)\nИмя: \(user.displayName)\nUsername: \(user.username ?? "-")\nСоздан: \(dateString(user.createdAt))\nАктивен: \(dateString(user.lastActiveAt))\nGifts: \(user.sentGifts)/\(user.receivedGifts)\nВыдано⭐️: \(user.grantedStars)\nТеги: \(user.tags.joined(separator: ", "))\nЗаметки: \(user.notes.isEmpty ? "-" : user.notes)"
            presentImpl?(textAlertController(
                context: context,
                updatedPresentationData: nil,
                title: user.displayName,
                text: details,
                actions: [
                    TextAlertAction(type: .genericAction, title: blockedTitle, action: {
                        JutsoLocalFeatures.shared.toggleBlocked(userId: user.userId)
                        refresh()
                    }),
                    TextAlertAction(type: .defaultAction, title: "OK", action: {})
                ]
            ))
        }
    )

    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), refreshToken.get())
    |> map { presentationData, state, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let snap = JutsoLocalFeatures.shared.snapshot()
        let users = JutsoLocalFeatures.shared.listUsers()
        let gifts = JutsoLocalFeatures.shared.listGifts(limit: 5)
        let cfg = JutsoLocalFeatures.shared.getStartupPopup()
        let aboutLink = JutsoLocalFeatures.shared.getAboutLink()
        let maintenanceMessage = JutsoLocalFeatures.shared.getMaintenanceMessage()
        let aiKeyStatus = JppgramAIKeyStore.hasKey() ? "SET" : "EMPTY"

        var entries: [JutsoAdminPanelEntry] = []
        entries.append(.dashboard(presentationData.theme, "Install: \(dateString(snap.installTimestamp))\nOwnerID: \(snap.localProfileId)\nUsers: \(snap.usersCount) • Gifts: \(snap.giftsCount)\nBalance: \(snap.starsBalance)⭐️\nLastAction: \(dateString(snap.lastActionTimestamp))"))

        let toggles: [(Int32, String, JutsoLocalFeatures.FeatureFlag)] = [
            (0, "Gifts", .giftsEnabled),
            (1, "AI", .aiEnabled),
            (2, "Admin tools", .adminToolsEnabled),
            (3, "Demo sync", .demoNetworkSync),
            (4, "Maintenance", .maintenanceMode)
        ]
        for (id, title, flag) in toggles {
            let value = JutsoLocalFeatures.shared.isEnabled(flag) ? "ON" : "OFF"
            entries.append(.toggle(id, presentationData.theme, "\(title)", value))
        }

        entries.append(.input(0, presentationData.theme, "SearchID", state.searchId, "ID для поиска", .number))
        entries.append(.input(1, presentationData.theme, "GrantID", state.grantId, "ID кому выдать ⭐️", .number))
        entries.append(.input(2, presentationData.theme, "GrantAmount", state.grantAmount, "Сумма ⭐️", .number))
        entries.append(.input(3, presentationData.theme, "SetBalance", state.setBalance, "Установить баланс ⭐️", .number))

        entries.append(.input(10, presentationData.theme, "AboutLink", state.aboutLink.isEmpty ? aboutLink : state.aboutLink, "Ссылка About", .regular))
        entries.append(.action(10, presentationData.theme, "Сохранить About link"))

        entries.append(.toggle(20, presentationData.theme, "Startup popup", cfg.enabled ? "ON" : "OFF"))
        entries.append(.input(21, presentationData.theme, "PopupTitle", state.popupTitle.isEmpty ? cfg.title : state.popupTitle, "Заголовок popup", .regular))
        entries.append(.input(22, presentationData.theme, "PopupText", state.popupText.isEmpty ? cfg.text : state.popupText, "Текст popup", .regular))
        entries.append(.input(23, presentationData.theme, "PopupUrl", state.popupUrl.isEmpty ? cfg.url : state.popupUrl, "Ссылка кнопки/URL", .regular))
        entries.append(.input(24, presentationData.theme, "PopupEvery", state.popupEvery, "Показывать раз в N запусков", .number))
        entries.append(.action(11, presentationData.theme, "Сохранить startup popup"))
        entries.append(.action(12, presentationData.theme, "Показать popup сейчас (demo)"))

        entries.append(.input(30, presentationData.theme, "MaintenanceMessage", state.maintenanceMessage.isEmpty ? maintenanceMessage : state.maintenanceMessage, "Сообщение maintenance", .regular))
        entries.append(.action(15, presentationData.theme, "Сохранить maintenance message"))

        entries.append(.input(40, presentationData.theme, "AIKey", state.aiKeyInput, "AI API key (Keychain) • \(aiKeyStatus)", .password))
        entries.append(.action(13, presentationData.theme, "Сохранить AI key"))
        entries.append(.action(14, presentationData.theme, "Удалить AI key"))

        entries.append(.action(0, presentationData.theme, "Выдать себе +500⭐️"))
        entries.append(.action(7, presentationData.theme, "Выдать ⭐️ пользователю (по ID/Amount выше)"))
        entries.append(.action(6, presentationData.theme, "Установить баланс (по полю выше)"))
        entries.append(.action(1, presentationData.theme, "Создать demo‑пользователя"))
        entries.append(.action(2, presentationData.theme, "Очистить историю подарков"))
        entries.append(.action(3, presentationData.theme, "Очистить логи"))
        entries.append(.action(4, presentationData.theme, "Экспорт JSON (копия в буфер)"))
        entries.append(.action(5, presentationData.theme, "Импорт JSON (из буфера)"))
        entries.append(.action(9, presentationData.theme, "Сбросить локальную базу"))
        entries.append(.action(8, presentationData.theme, "Заблокировать админ‑панель"))

        for (i, user) in users.prefix(20).enumerated() {
            entries.append(.user(Int32(i), presentationData.theme, "\(user.displayName) • \(user.userId)", userLabel(user)))
        }

        if !gifts.isEmpty {
            for (i, gift) in gifts.enumerated() {
                entries.append(.log(Int32(i), presentationData.theme, "Gift: \(giftLine(gift))"))
            }
        }
        let recentLogs = JutsoLocalFeatures.shared.exportBundle().logs.suffix(20)
        if !recentLogs.isEmpty {
            var idx: Int32 = 1000
            for line in recentLogs {
                entries.append(.log(idx, presentationData.theme, line))
                idx += 1
            }
        }
        entries.append(.info(presentationData.theme, "Админ‑панель локальная. Код по умолчанию: \(JutsoLocalFeatures.shared.secretCodeHint())."))

        let controllerState = ItemListControllerState(
            presentationData: ItemListPresentationData(presentationData),
            title: .text("j++gram Admin"),
            leftNavigationButton: nil,
            rightNavigationButton: nil,
            backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back),
            animateChanges: true
        )
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    controller.didAppear = { _ in
        refresh()
    }
    presentImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

