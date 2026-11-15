import Foundation

enum PauseReason: Hashable {
    case systemSleep, displaySleep, sessionInactive
}

/// Sampling pauses while any reason holds and resumes when the last one
/// clears. Duplicate or unmatched notifications are no-ops, so the timer
/// stops and restarts exactly once per pause.
struct PauseState {
    private(set) var reasons: Set<PauseReason> = []

    var isPaused: Bool { !reasons.isEmpty }

    /// True only on the transition from running to paused.
    mutating func pause(_ reason: PauseReason) -> Bool {
        let wasPaused = isPaused
        reasons.insert(reason)
        return !wasPaused
    }

    /// True only on the transition from paused to running.
    mutating func resume(_ reason: PauseReason) -> Bool {
        guard reasons.remove(reason) != nil else { return false }
        return !isPaused
    }
}
