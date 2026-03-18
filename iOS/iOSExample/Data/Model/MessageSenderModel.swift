import Foundation
import SQLiteData

@Table("messageSenders")
struct MessageSenderModel {
  var id: UUID = .init()
  var pubkey: Data
  /// codename
  var codename: String
  /// User-set nickname (optional)
  var nickname: String?
  /// DM token for direct messaging (optional - nil means DM is disabled)
  var dmToken: Int32?

  var color: Int
  init(
    pubkey: Data, codename: String, nickname: String?, dmToken: Int32?,
    color: Int
  ) {
    self.pubkey = pubkey
    self.codename = codename
    self.nickname = nickname
    self.dmToken = dmToken
    self.color = color
  }

  private init() {
    self.pubkey = Data()
    self.codename = ""
    self.color = 0
    self.id = UUID.selfId
  }

  static func selfSender() -> MessageSenderModel {
    return MessageSenderModel()
  }
}
