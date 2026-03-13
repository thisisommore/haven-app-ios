import Foundation
import SQLiteData

@Table("messageSenders")
struct MessageSenderModel: Encodable {
  var id: String
  var pubkey: Data
  /// codename
  var codename: String
  /// User-set nickname (optional)
  var nickname: String?
  /// DM token for direct messaging (optional - nil means DM is disabled)
  var dmToken: Int32

  var color: Int
  init(
    id: String, pubkey: Data, codename: String, nickname: String? = nil, dmToken: Int32 = 0,
    color: Int
  ) {
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
    try c.encode(self.id, forKey: .id)
    try c.encode(self.pubkey, forKey: .pubkey)
    try c.encode(self.dmToken, forKey: .dmToken)
    try c.encode(self.codename, forKey: .codename)
    try c.encode(self.nickname, forKey: .nickname)
    try c.encode(self.color, forKey: .color)
  }
}
