import Foundation

/// Internal mutable accumulator for per-pass extraction diagnostics.
/// Incrementally populated as extraction proceeds; converted to `InspectionReport` on completion.
final class InspectionContext {

    // MARK: - Internal Raw Data Structures

    struct RawClassWeightComponent {
        let attribute: String
        let side: String
        let matchedPatterns: [String]
        let points: Double
    }

    struct RawCandidateInfo {
        let descriptor: String
        let depth: Int
        let finalScore: Double
        let baseScore: Double
        let classWeightTotal: Double
        let classWeightComponents: [RawClassWeightComponent]
        let childrenScore: Double
    }

    struct RawPromotionStep {
        let descriptor: String
        let score: Double
        let action: String
    }

    struct RawPass {
        var passNumber: Int
        var flagBits: UInt32
        var topCandidates: [RawCandidateInfo] = []
        var initialWinner: RawCandidateInfo?
        var promotionTrace: [RawPromotionStep] = []
        var finalCandidate: RawCandidateInfo?
        var contentLength: Int = 0
        var accepted: Bool = false
    }

    // MARK: - State

    private var passes: [RawPass] = []
    private var currentPass: RawPass?

    /// Flag bits of the currently active pass (used by CandidateSelector to branch on flag state).
    var currentPassFlagBits: UInt32 { currentPass?.flagBits ?? 0 }

    // MARK: - Pass Lifecycle

    func beginPass(number: Int, flagBits: UInt32) {
        currentPass = RawPass(passNumber: number, flagBits: flagBits)
    }

    func recordTopCandidates(_ candidates: [RawCandidateInfo]) {
        currentPass?.topCandidates = candidates
    }

    func recordInitialWinner(_ info: RawCandidateInfo?) {
        currentPass?.initialWinner = info
    }

    func recordPromotionStep(descriptor: String, score: Double, action: String) {
        currentPass?.promotionTrace.append(
            RawPromotionStep(descriptor: descriptor, score: score, action: action)
        )
    }

    func recordFinalCandidate(_ info: RawCandidateInfo?) {
        currentPass?.finalCandidate = info
    }

    func endPass(contentLength: Int, accepted: Bool) {
        guard var pass = currentPass else { return }
        pass.contentLength = contentLength
        pass.accepted = accepted
        passes.append(pass)
        currentPass = nil
    }

    // MARK: - Report Construction

    func buildReport(charThreshold: Int) -> InspectionReport {
        InspectionReport(passes: passes.map { buildPassAttempt($0, charThreshold: charThreshold) })
    }

    private func buildPassAttempt(_ raw: RawPass, charThreshold: Int) -> InspectionReport.PassAttempt {
        InspectionReport.PassAttempt(
            passNumber: raw.passNumber,
            activeFlags: flagNames(raw.flagBits),
            topCandidates: raw.topCandidates.map(makePublicCandidateInfo),
            initialWinner: raw.initialWinner.map(makePublicCandidateInfo),
            promotionTrace: raw.promotionTrace.map {
                InspectionReport.PromotionStep(
                    descriptor: $0.descriptor, score: $0.score, action: $0.action)
            },
            finalCandidate: raw.finalCandidate.map(makePublicCandidateInfo),
            contentLength: raw.contentLength,
            charThreshold: charThreshold,
            accepted: raw.accepted
        )
    }

    private func makePublicCandidateInfo(_ raw: RawCandidateInfo) -> InspectionReport.CandidateInfo {
        InspectionReport.CandidateInfo(
            descriptor: raw.descriptor,
            depth: raw.depth,
            score: raw.finalScore,
            baseScore: raw.baseScore,
            classWeightTotal: raw.classWeightTotal,
            classWeightComponents: raw.classWeightComponents.map {
                InspectionReport.ClassWeightComponent(
                    attribute: $0.attribute,
                    side: $0.side,
                    matchedPatterns: $0.matchedPatterns,
                    points: $0.points
                )
            },
            childrenScore: raw.childrenScore
        )
    }

    private func flagNames(_ bits: UInt32) -> [String] {
        var names: [String] = []
        if bits & Configuration.flagStripUnlikelies    != 0 { names.append("STRIP") }
        if bits & Configuration.flagWeightClasses      != 0 { names.append("WEIGHT") }
        if bits & Configuration.flagCleanConditionally != 0 { names.append("CLEAN") }
        return names
    }
}
