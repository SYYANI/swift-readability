import Testing
import Foundation
@testable import Readability

/// Compatibility tests for cases captured via ReadabilityCLI (ex-pages/).
///
/// Each test method corresponds to one case committed with `swift run ReadabilityCLI commit`.
/// Add methods here manually after running `commit` — the command prints a ready-to-use template.
@Suite("Ex-pages Compatibility Tests")
struct ExPagesCompatibilityTests {

    private let defaultOptions = ReadabilityOptions(
        charThreshold: 500,
        classesToPreserve: ["caption"]
    )

    // MARK: - Tests
    //
    // (empty — add test methods here as cases are committed)
}
