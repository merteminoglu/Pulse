import Foundation

/// A bounded cache that keeps what was used recently without tracking
/// recency per entry: two generations, and when the current one fills it
/// becomes the previous one and the oldest generation is dropped. A hit in
/// the previous generation moves the entry forward, so values in steady use
/// survive every rotation.
struct GenerationCache<Key: Hashable, Value> {
    private let generationSize: Int
    private var current: [Key: Value] = [:]
    private var previous: [Key: Value] = [:]

    init(generationSize: Int) {
        self.generationSize = max(1, generationSize)
    }

    /// Never more than twice the generation size.
    var count: Int { current.count + previous.count }

    mutating func value(for key: Key, make: () -> Value) -> Value {
        if let hit = current[key] { return hit }
        let value = previous.removeValue(forKey: key) ?? make()
        if current.count >= generationSize {
            previous = current
            current = [:]
        }
        current[key] = value
        return value
    }
}
