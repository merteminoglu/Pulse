import Foundation

struct RingBuffer<Element> {
    private var storage: [Element?]
    private var head: Int = 0
    private(set) var count: Int = 0
    let capacity: Int

    init(capacity: Int = Tokens.historyLength) {
        let cap = max(1, capacity)
        self.capacity = cap
        self.storage = Array(repeating: nil, count: cap)
    }

    mutating func append(_ e: Element) {
        storage[head] = e
        head = (head + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    var elements: [Element] {
        guard count > 0 else { return [] }
        var result: [Element] = []
        result.reserveCapacity(count)
        let start = count == capacity ? head : 0
        for i in 0..<count {
            let idx = (start + i) % capacity
            if let el = storage[idx] {
                result.append(el)
            }
        }
        return result
    }

    var last: Element? {
        guard count > 0 else { return nil }
        let lastIndex = (head - 1 + capacity) % capacity
        return storage[lastIndex]
    }

    var isFull: Bool {
        count == capacity
    }
}
