import Foundation
import GRDB

struct MessageSenderModel: Identifiable, Codable, FetchableRecord, PersistableRecord, Encodable {
    static let databaseTableName = "messageSenderModel"

    var id: String
    var pubkey: Data
    // codename
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
}
