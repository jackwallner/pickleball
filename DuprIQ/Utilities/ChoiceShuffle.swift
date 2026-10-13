import Foundation

/// Deterministic answer-position shuffling. The correct choice must not
/// always sit in the authored slot (usually index 0), but the order has to
/// stay STABLE for a given item across re-renders, undo, and back-nav. A
/// permutation seeded purely by the item's id gives both: same id -> same
/// order, every time, with no stored random state.
enum ChoiceShuffle {

    /// A permutation of `0..<count`: `permutation[displayPosition]` is the
    /// original index that should render at `displayPosition`.
    static func permutation(count: Int, seed: String) -> [Int] {
        guard count > 1 else { return Array(0..<count) }
        var generator = StableSeededGenerator(seed: seed)
        var indices = Array(0..<count)
        indices.shuffle(using: &generator)
        return indices
    }

    /// Shuffles a labeled choice list and remaps the correct index through
    /// the same permutation. Grading must compare against the returned
    /// `answerIndex`, not the original one.
    static func shuffledChoices(labels: [String], answerIndex: Int, seed: String) -> (labels: [String], answerIndex: Int) {
        let perm = permutation(count: labels.count, seed: seed)
        let shuffledLabels = perm.map { labels[$0] }
        let shuffledAnswerIndex = perm.firstIndex(of: answerIndex) ?? answerIndex
        return (shuffledLabels, shuffledAnswerIndex)
    }
}

/// FNV-1a backed generator: plain string hash, not Swift's per-process
/// `Hasher`, so the same seed produces the same stream across launches.
struct StableSeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        state = hash == 0 ? 0x9E3779B97F4A7C15 : hash
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state &* 2685821657736338717
    }
}
