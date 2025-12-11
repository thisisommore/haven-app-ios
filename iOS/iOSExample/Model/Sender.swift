import Foundation
import SwiftData

@Model
class Sender: Encodable {
    @Attribute(.unique) var id: String
    var pubkey: Data
    //codename
    var codename: String
    // User-set nickname (optional)
    var nickname: String?
    // DM token for direct messaging (optional - nil means DM is disabled)
    var dmToken: Int32
    
    var color: Int
    init(id: String, pubkey: Data, codename: String, nickname: String? = nil, dmToken: Int32 = 0, color: Int) {
        self.id = id
        self.pubkey = pubkey
        self.codename = codename
        self.nickname = nickname
        self.dmToken = dmToken
        self.color = color
    }
    
    enum CodingKeys: String, CodingKey {
        case id, pubkey, codename, nickname, dmToken, color
    }
    
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id);
        try c.encode(pubkey, forKey: .pubkey);
        try c.encode(dmToken, forKey: .dmToken)
        try c.encode(codename, forKey: .codename)
        try c.encode(nickname, forKey: .nickname)
        try c.encode(color, forKey: .color)
    }
}

