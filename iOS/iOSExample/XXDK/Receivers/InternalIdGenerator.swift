import Foundation

/// Thread-safe atomic counter for generating unique Int64 IDs
final class InternalIdGenerator {
  static let shared = InternalIdGenerator()
  private var counter: Int64
  private let lock = NSLock()
  private let key = "InternalIdGenerator.counter"

  private init() {
    self.counter = Int64(UserDefaults.standard.integer(forKey: self.key))
  }

  func next() -> Int64 {
    self.lock.lock()
    defer { lock.unlock() }
    self.counter += 1
    UserDefaults.standard.set(Int(self.counter), forKey: self.key)
    return self.counter
  }
}
