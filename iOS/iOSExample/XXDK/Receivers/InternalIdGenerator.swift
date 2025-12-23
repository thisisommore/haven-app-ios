import Foundation

/// Thread-safe atomic counter for generating unique Int64 IDs
final class InternalIdGenerator {
    static let shared = InternalIdGenerator()
    private var counter: Int64
    private let lock = NSLock()
    private let key = "InternalIdGenerator.counter"

    private init() {
        counter = Int64(UserDefaults.standard.integer(forKey: key))
    }

    func next() -> Int64 {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
        UserDefaults.standard.set(Int(counter), forKey: key)
        return counter
    }
}
