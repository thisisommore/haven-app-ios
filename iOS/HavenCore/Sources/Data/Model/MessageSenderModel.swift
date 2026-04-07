import Foundation
import SQLiteData

@Table("messageSenders")
public struct MessageSenderModel: Hashable, Sendable {
  public var id: UUID = .init()
  public var pubkey: Data
  /// codename
  public var codename: String
  /// User-set nickname (optional)
  public var nickname: String?
  /// DM token for direct messaging (optional - nil means DM is disabled)
  public var dmToken: Int32?

  public var color: Int
  public init(
    pubkey: Data, codename: String, nickname: String?, dmToken: Int32?,
    color: Int
  ) {
    self.pubkey = pubkey
    self.codename = codename
    self.nickname = nickname
    self.dmToken = dmToken
    self.color = color
  }

  private init(pubkey: Data) {
    self.pubkey = pubkey
    self.codename = ""
    self.color = 0
    self.id = UUID.selfId
  }

  public static func selfSender(pubkey: Data) -> MessageSenderModel {
    return MessageSenderModel(pubkey: pubkey)
  }
}
