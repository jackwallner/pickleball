import XCTest
@testable import DuprIQ

/// Writes a sample of generated positions, options and verdicts to
/// build/content-sample.md for a coaching review. Runs only when
/// CONTENT_DUMP=1, so the normal suite stays instant.
final class ContentDumpTests: XCTestCase {
    func testDumpContentSample() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["CONTENT_DUMP"] == "1")
        var out = "# Generated content sample\n\n"
        for phase in RallyPhase.allCases {
            out += "## \(phase.title)\n\n"
            for seed in UInt64(1)...25 {
                let q = PositionGenerator.question(phase: phase, seed: seed &* 7_919)
                let traps = MistakeCatalog.mistakes(for: q)
                out += "### \(phase.rawValue) #\(seed)\n"
                out += q.position.spokenDescription() + " Ball: \(q.position.ballHeight).\n\n"
                for (i, shot) in q.options.enumerated() {
                    let mark = i == q.answerIndex ? "BEST" : (traps[shot.label].map { "trap: \($0.title)" } ?? "")
                    out += "- \(i + 1). \(shot.label) \(mark)\n"
                }
                out += "\nPrinciple: \(q.verdict.principle)\n\nWhy: \(q.verdict.why)\n\n"
            }
        }
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        try out.write(to: repo.appendingPathComponent("build/content-sample.md"), atomically: true, encoding: .utf8)
    }
}
