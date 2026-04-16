import Foundation
import TelegramCore
import Postbox

/// Custom message attribute for virtual gifts
/// Only visible to Hakogram users
public class GiftMessageAttribute: MessageAttribute {
    public let giftType: VirtualStarsManager.NFTGift
    public let senderId: Int64
    public let timestamp: Int32
    
    public init(giftType: VirtualStarsManager.NFTGift, senderId: Int64) {
        self.giftType = giftType
        self.senderId = senderId
        self.timestamp = Int32(Date().timeIntervalSince1970)
    }
    
    required public init(decoder: PostboxDecoder) {
        if let giftString = decoder.decodeOptionalStringForKey("gift"),
           let gift = VirtualStarsManager.NFTGift(rawValue: giftString) {
            self.giftType = gift
        } else {
            self.giftType = .star
        }
        self.senderId = decoder.decodeInt64ForKey("senderId", orElse: 0)
        self.timestamp = decoder.decodeInt32ForKey("timestamp", orElse: 0)
    }
    
    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeString(giftType.rawValue, forKey: "gift")
        encoder.encodeInt64(senderId, forKey: "senderId")
        encoder.encodeInt32(timestamp, forKey: "timestamp")
    }
    
    public static var associatedMessageIds: [MessageId] {
        return []
    }
    
    public static var associatedPeerIds: [PeerId] {
        return []
    }
}

// Extension to check if message has gift
extension Message {
    public var hakogramGift: VirtualStarsManager.NFTGift? {
        for attribute in self.attributes {
            if let giftAttr = attribute as? GiftMessageAttribute {
                return giftAttr.giftType
            }
        }
        return nil
    }
    
    public var hasHakogramGift: Bool {
        return hakogramGift != nil
    }
}
