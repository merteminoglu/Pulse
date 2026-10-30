import Foundation

protocol Sampler: AnyObject {
    associatedtype Output
    func sample(now: ContinuousClock.Instant) -> Output?   // nil = not enough data yet / unavailable
    func reset()                                           // drop baselines (wake, interface change)
}
