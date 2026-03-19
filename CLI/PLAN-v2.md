# Readability CLI v2 Refactoring Plan (Issue Capture & Ground Truth Toolchain)

## 1. Background & Motivation

As the Readability library sees wider use in the RSS reader app Mercury, edge cases and site-specific extraction failures are inevitable. To make fault diagnosis systematic and to prevent regressions, the existing CLI tool will be thoroughly redesigned.

**Limitations of the current CLI and rationale for redesign:**

1. **Basic parsing is superseded**: The original "input HTML, output result" flow is fully covered by the new pipeline design.
2. **Benchmarking and profiling removed**: The existing benchmark tool, profiling infrastructure, and `Instrumentation.swift` in the main library (which used `os_signpost` for performance tracing) were not reliable in practice. All of these will be deleted in this refactor. Performance tooling will be redesigned from scratch when genuine need arises.
3. **Isolated incremental baseline**: Newly captured test cases will live in `Tests/ReadabilityTests/Resources/ex-pages/`, kept separate from Mozilla's official baseline (`test-pages/` and `realworld-pages/`). The name `ex-pages` denotes test cases added beyond the Mozilla official test set.

The redesigned CLI becomes an **Issue Capture & Ground Truth Calibration Pipeline** — a set of cohesive, composable atomic subcommands. The working directory remains `CLI/`, with a local staging area for in-progress work. Once a case is finalized, it is promoted into the main library's test suite.

---

## 2. Prerequisites

The `parse` command requires **Node.js** (`node` on `$PATH`) to execute the reference Mozilla Readability.js implementation for side-by-side comparison.

The bridge script (`CLI/scripts/mozilla-bridge.js`) uses CommonJS modules and `jsdom`, neither of which Deno supports out of the box. Node.js is the only supported runtime.

First-time setup for the bridge script:
```bash
cd CLI/scripts && npm install
```

---

## 3. Invoking the Tool

From within the `CLI/` directory:

```bash
swift run ReadabilityCLI <subcommand> [arguments]
```

A convenience shell script wrapper at the repo root may be added in a future iteration for brevity.

---

## 4. Core Architecture & Staging Area Design

The CLI operates on a local staging area at `CLI/.staging/<case-name>/`. This directory is listed in `.gitignore` and is never committed to the repository.

A complete case lifecycle may produce the following files within the staging directory:

| File | Description |
|---|---|
| `source.html` | Raw HTML snapshot taken at fetch time |
| `meta.json` | Fetch metadata (origin URL, timestamp) |
| `swift-out.html` | Content extracted by the Swift library |
| `swift-result.json` | Metadata extracted by the Swift library |
| `mozilla-out.html` | Content extracted by Mozilla Readability.js |
| `mozilla-result.json` | Metadata extracted by Mozilla Readability.js |
| `draft-expected.html` | Candidate ground truth (for human review) |
| `draft-expected-metadata.json` | Candidate metadata (for human review) |
| `expected.html` | Finalized ground truth content |
| `expected-metadata.json` | Finalized ground truth metadata |

**Case identity**: Once established by `fetch --name <case-name>`, all subsequent subcommands accept `<case-name>` as the sole case identifier. The `.staging/<case-name>/` path is an internal detail that users never need to type directly.

**Immutability policy**: Captured cases (`source.html`) are never updated in place. If a site changes and a new extraction issue arises, it is a new case with a new name.

---

## 5. Subcommand Design

The pipeline is composed of seven atomic subcommands plus one diagnostic tool.

### 5.1 `fetch` — Snapshot Acquisition
**Goal**: Freeze the page at the moment a problem is observed, eliminating the effect of dynamic content changes.
- **Syntax**: `ReadabilityCLI fetch <URL> --name <case-name>`
- **Process**:
  1. Validate the URL: only `http`/`https` schemes accepted; private/loopback ranges (`127.x`, `10.x`, `192.168.x`, `169.254.x`, `::1`) rejected; configurable timeout applies.
  2. Download the complete HTML of the page.
  3. Create `CLI/.staging/<case-name>/`.
  4. Write `source.html` and `meta.json` (recording origin URL and fetch timestamp).
- **Output**: Staging base files ready for subsequent steps.

### 5.2 `parse` — Dual-Engine Comparison
**Goal**: Run `source.html` through both the Swift library and Mozilla Readability.js, surfacing divergences and defects.
- **Syntax**: `ReadabilityCLI parse <case-name>`
- **Process**:
  1. **Swift side**: Invoke `Sources/Readability`, write `swift-out.html` and `swift-result.json` to staging.
  2. **Mozilla side**: Invoke the JS bridge script at `CLI/scripts/mozilla-bridge.js` via `Process`, using Node.js and `ref/mozilla-readability`. Write `mozilla-out.html` and `mozilla-result.json` to staging. The bridge script accepts the path to `source.html` as input and emits JSON to stdout.
- **Output**: Four comparison files written to the staging directory.

### 5.3 `review` — Side-by-Side Visual Comparison
**Goal**: Let the developer see at a glance how the Swift and Mozilla outputs differ, before deciding what the correct ground truth should be.
- **Syntax**: `ReadabilityCLI review <case-name>`
- **Process**:
  1. Read whatever output files are present in staging: `swift-out.html`, `mozilla-out.html`, and `draft-expected.html` (if it exists).
  2. Generate a self-contained `report.html` with one column per available file; each column renders the extracted content in an iframe.
  3. Open `report.html` in the default browser.
- **Design rationale**: Uses `srcdoc` iframes (not `src=`) to guarantee cross-browser local file loading without an HTTP server.
- **Output**: `report.html` written to the shared location `CLI/.staging/report.html` (overwritten on every invocation). Not stored per-case. No other files overwritten.

### 5.4 `judge` — Ground Truth Draft Generation
**Goal**: Provide a starting point for "what the correct output should look like", reducing manual effort.
- **Syntax**: `ReadabilityCLI judge <case-name> [--strategy <mozilla|ai>]`
- **Strategies**: `mozilla` (default): copies `mozilla-out.html` as `draft-expected.html`; `ai` (Phase 3, experimental): details TBD when implemented.
- **Output**: `draft-expected.html` and `draft-expected-metadata.json` written to staging.

### 5.5 `commit` — Test Case Promotion
**Goal**: Copy a finalized case into the library's test suite so development can begin against it.
- **Syntax**: `ReadabilityCLI commit <case-name>`
- **Process**:
  1. Validate that staging contains `source.html`, `expected.html`, and `expected-metadata.json`. If only `draft-expected.*` exist, print an instructive error.
  2. Copy the three files into `Tests/ReadabilityTests/Resources/ex-pages/<case-name>/`.
  3. Print a template snippet for adding a test method to `ExPagesCompatibilityTests.swift` (see Section 6).
- **Non-destructive**: Staging directory is NOT cleaned up. Use `clean` explicitly.
- **Output**: Test case files written to `ex-pages/`. Staging untouched.

---

### 5.6 `clean` — Staging Cleanup
**Goal**: Remove staging files when they are no longer needed.
- **Syntax**: `ReadabilityCLI clean <case-name>` (one case) or `ReadabilityCLI clean` (entire `.staging/`).
- **Process**: Prompts for confirmation, then deletes the specified staging directory. Does not affect anything under `Tests/`.

---

### 5.7 `inspect` — White-Box Diagnostics

**Goal**: When a case is under active investigation, surface the library's full internal decision trace so that root causes can be identified without inserting any temporary debug code into the source.

**Design principle**: `inspect` is considered complete when the following completeness test is satisfied — given a known case like `1a23-1`, the inspect output alone (without reading source code) must be sufficient to identify both root causes: the buggy flag-removal sequence (`tryNextFlag`) and the ancestor initialization ignoring the `FLAG_WEIGHT_CLASSES` state.

- **Syntax**: `ReadabilityCLI inspect <case-name>`

#### Minimum Necessary Trace Items

Four trace items form the minimum sufficient set for diagnosing extraction failures:

1. **Pass trace** — For each multi-pass attempt, show: which flags were active (`STRIP`, `WEIGHT`, `CLEAN`), the resulting content length, whether the charThreshold was met, and whether the attempt was accepted or retried.

2. **Candidate scores** — For each pass, show the top-N scored candidate nodes with: tag/id/class descriptor, DOM depth, final score, and score breakdown (base tag score + class weight + children propagation total).

3. **Class weight breakdown** — For each candidate, enumerate which positive/negative regex patterns matched its class/id, and the exact points contributed by each match. This makes it immediately visible when an incidental class name like `ghostkit-icon-box-content` is erroneously triggering a `+25` bonus.

4. **Promotion trace** — When `findBetterParentCandidate` elevates the initial winner up the ancestor chain, show the full path: each ancestor node, its score, and the direction of change (rising/falling) that triggered or blocked promotion.

#### Example Output

```
Pass 1  [STRIP | WEIGHT | CLEAN]   content=247 chars < threshold=500 → retry
Pass 2  [WEIGHT | CLEAN]           content=247 chars < threshold=500 → retry
Pass 3  [CLEAN]                    content=2847 chars ≥ threshold=500 → accepted

Top candidates (Pass 3, flags=CLEAN):
  #1  div.ghostkit-icon-box-content  depth=7  score=11.000
      base=5  classWeight=0 (WEIGHT flag off)  children=+6.0
  #2  div.entry-content              depth=5  score=10.838  ← selected via promotion
      base=5  classWeight=0 (WEIGHT flag off)  children=+5.838

Promotion trace from #1:
  div.ghostkit-icon-box-content  score=11.000  lastScore=11.000
  div.ghostkit-icon-box          score= 8.000  ↓ fell, continue scanning
  div.entry-content              score=10.838  ↑ rose above lastScore=8.000 → PROMOTED

Class weight reference (Pass 1, flags=STRIP|WEIGHT|CLEAN):
  div.ghostkit-icon-box-content  +25.0  matched pattern: "content"
  div.entry-content              +25.0  matched pattern: "entry" (+12.5), "content" (+12.5)
```

#### Implementation Architecture

- Add `InspectionReport` to the library (not to CLI) as a public struct returned by a new `parseWithInspection()` method (or via an options callback). Zero overhead when not invoked.
- `InspectionReport` contains:
  - `passes: [PassAttempt]` — one entry per `_grabArticle` loop iteration
  - `PassAttempt`: `flagState: [String]`, `topCandidates: [CandidateInfo]`, `selectedCandidate: CandidateInfo?`, `contentLength: Int`, `accepted: Bool`
  - `CandidateInfo`: `descriptor: String`, `depth: Int`, `score: Double`, `baseScore: Double`, `classWeightBreakdown: [(pattern: String, points: Double)]`, `childrenScore: Double`, `promotedFrom: CandidateInfo?`
- The CLI `inspect` command calls `parseWithInspection()`, formats `InspectionReport` for terminal output, and writes it to stdout.

- **Diagnostic guidance**: After reading inspect output, apply the same decision framework used in the Site Rule architecture:
  - If flag logic, scoring algorithm, or broadly applicable heuristics are wrong → fix **core algorithms**.
  - If the root cause is brand-specific class names or proprietary DOM structure → write a **Site Rule**.

---

## 6. Test Integration

The `ex-pages/` test cases follow the same conventions as `realworld-pages/` tests. No changes to `TestLoader.swift` or existing test infrastructure are required.

A dedicated file `Tests/ReadabilityTests/ExPagesCompatibilityTests.swift` holds one test method per case, added **manually** after running `commit`. The `commit` command prints a ready-to-use template snippet:

```swift
@Test("<case-name> - Title matches expected")
func test<CaseName>Title() async throws {
    guard let testCase = TestLoader.loadTestCase(named: "<case-name>", in: "ex-pages") else {
        Issue.record("Failed to load test case")
        return
    }
    let result = try Readability(html: testCase.sourceHTML, options: defaultOptions).parse()
    #expect(result.title == testCase.expectedMetadata.title)
}
```

The `expected-metadata.json` format matches the Mozilla test page schema exactly, which maps directly to `ReadabilityResult` field names.

---

## 7. Implementation Phases

### Phase 1: Core Pipeline (Scaffold & Automation)
1. **Clean up the current CLI**: Delete benchmark components, the profiling infrastructure, and `Instrumentation.swift` from the main library.
2. **Add `swift-argument-parser`** to `CLI/Package.swift` and rebuild the CLI with a multi-subcommand architecture.
3. **Add `CLI/.staging/` to `.gitignore`**.
4. **Implement `fetch`, `parse`, `review`, `commit`, `clean`**:
   - Write the Mozilla JS bridge script at `CLI/scripts/mozilla-bridge.js`.
   - Run `npm install` in `CLI/scripts/` to install `jsdom`.
   - Implement Node.js detection and subprocess invocation in the `parse` command.
5. **Create `ExPagesCompatibilityTests.swift`** as an empty-but-compilable placeholder, to be filled case-by-case.

From Phase 1 onward, `judge` remains **manual**: copy `mozilla-out.html` to `draft-expected.html`, edit as needed, rename to `expected.*`, then call `commit`.

### Phase 2: Diagnostics System
1. Add `InspectionReport`, `PassAttempt`, and `CandidateInfo` structs to the main library (public API, `Sendable`).
2. Add a `parseWithInspection() throws -> (result: ReadabilityResult, report: InspectionReport)` method to `Readability`, implemented as a zero-cost wrapper — diagnostics data is only collected when this path is taken.
3. Wire instrumentation points into `ContentExtractor` (pass-loop entry/exit), `CandidateSelector` (candidate scores, promotion path), and `NodeScoring` (class weight pattern matches).
4. Implement the `inspect` CLI subcommand: call `parseWithInspection()`, format `InspectionReport` for terminal output as shown in Section 5.7.

### Phase 3: Assisted Calibration (Judge)
1. Implement the `judge --strategy mozilla` default in code (manual copy in Phase 1).
2. (Experimental) Define the `judge --strategy ai` interface — opt-in flag, explicit user confirmation before any external call, no raw content forwarded without acknowledgment — and implement when requirements are clear.
