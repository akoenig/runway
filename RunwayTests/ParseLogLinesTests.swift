import Testing
@testable import Runway

// MARK: - Helpers

/// Convenience to build a `WorkflowStep` array for testing.
/// Only `number` and `name` matter to the parser; the rest are fillers.
private func makeSteps(_ pairs: [(number: Int, name: String)]) -> [WorkflowStep] {
    pairs.map {
        WorkflowStep(
            number: $0.number,
            name: $0.name,
            status: "completed",
            conclusion: "success",
            startedAt: nil,
            completedAt: nil
        )
    }
}

// MARK: - Basic Behaviour

@Test("Empty input produces no log lines")
func emptyLog() {
    let result = GitHubService.parseLogLines("", steps: [])
    #expect(result.isEmpty)
}

@Test("Whitespace-only lines are filtered out")
func blankLinesSkipped() {
    let raw = """
    2024-01-15T10:00:00.0000000Z First line
    2024-01-15T10:00:01.0000000Z    \t  
    2024-01-15T10:00:02.0000000Z Second line
    """
    let steps = makeSteps([(1, "Set up job")])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 2)
    #expect(result[0].content == "First line")
    #expect(result[1].content == "Second line")
}

// MARK: - Timestamp Stripping

@Test("ISO8601 timestamp prefix is stripped from lines")
func timestampStripping() {
    let raw = "2024-01-15T10:23:45.1234567Z Hello world"
    let steps = makeSteps([(1, "Set up job")])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    #expect(result[0].content == "Hello world")
}

@Test("Lines without timestamps are preserved as-is")
func noTimestamp() {
    let raw = "No timestamp here"
    let steps = makeSteps([(1, "Set up job")])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    #expect(result[0].content == "No timestamp here")
}

// MARK: - ANSI Escape Code Stripping

@Test("ANSI color codes are stripped from content")
func ansiCodeStripping() {
    let raw = "2024-01-15T10:00:00.0000000Z \u{1B}[36;1mbrew install xcodegen\u{1B}[0m"
    let steps = makeSteps([(1, "Set up job")])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    #expect(result[0].content == "brew install xcodegen")
}

@Test("Multiple ANSI codes in a single line are all stripped")
func multipleAnsiCodes() {
    let raw = "2024-01-15T10:00:00.0000000Z \u{1B}[32m==>\u{1B}[0m \u{1B}[1mPouring xcodegen--2.44.1\u{1B}[0m"
    let steps = makeSteps([(1, "Set up job")])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    #expect(result[0].content == "==> Pouring xcodegen--2.44.1")
}

// MARK: - Group Markers

@Test("##[group] and ##[endgroup] lines are excluded from output")
func groupMarkersSkipped() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run echo hello
    2024-01-15T10:00:01.0000000Z hello
    2024-01-15T10:00:02.0000000Z ##[endgroup]
    """
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Say hello"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    #expect(result[0].content == "hello")
}

// MARK: - Error and Warning Detection

@Test("##[error] prefix is detected and stripped")
func errorLineDetection() {
    let raw = "2024-01-15T10:00:00.0000000Z ##[error]Process completed with exit code 1."
    let steps = makeSteps([(1, "Set up job")])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    #expect(result[0].isError == true)
    #expect(result[0].isWarning == false)
    #expect(result[0].content == "Process completed with exit code 1.")
}

@Test("##[warning] prefix is detected and stripped")
func warningLineDetection() {
    let raw = "2024-01-15T10:00:00.0000000Z ##[warning]Node.js 16 actions are deprecated."
    let steps = makeSteps([(1, "Set up job")])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    #expect(result[0].isWarning == true)
    #expect(result[0].isError == false)
    #expect(result[0].content == "Node.js 16 actions are deprecated.")
}

@Test("Regular lines are not flagged as error or warning")
func normalLineFlags() {
    let raw = "2024-01-15T10:00:00.0000000Z Just a regular line"
    let steps = makeSteps([(1, "Set up job")])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    #expect(result[0].isError == false)
    #expect(result[0].isWarning == false)
}

// MARK: - Step Mapping

@Test("Run groups map sequentially to user-facing steps")
func runGroupsMapToUserSteps() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run actions/checkout@v4
    2024-01-15T10:00:01.0000000Z with:
    2024-01-15T10:00:02.0000000Z ##[endgroup]
    2024-01-15T10:00:03.0000000Z Syncing repository
    2024-01-15T10:00:04.0000000Z ##[group]Run echo "VERSION=1.0"
    2024-01-15T10:00:05.0000000Z ##[endgroup]
    2024-01-15T10:00:06.0000000Z ##[group]Run brew install xcodegen
    2024-01-15T10:00:07.0000000Z ##[endgroup]
    2024-01-15T10:00:08.0000000Z Installing xcodegen...
    """
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Checkout"),
        (3, "Get version from tag"),
        (4, "Install XcodeGen"),
        (20, "Post Checkout"),
        (21, "Complete job"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)

    // "with:" is inside the group marker for step 2 (Checkout) but the line
    // itself follows after the ##[group] marker which triggers step assignment.
    // Actually, "with:" appears AFTER ##[group]Run actions/checkout@v4 which
    // sets currentStep to 2. The line "with:" is output since it doesn't start
    // with ##[.
    let checkoutLines = result.filter { $0.stepNumber == 2 }
    let versionLines = result.filter { $0.stepNumber == 3 }
    let installLines = result.filter { $0.stepNumber == 4 }

    // Checkout step gets "with:" and "Syncing repository"
    #expect(checkoutLines.count == 2)
    #expect(checkoutLines[0].content == "with:")
    #expect(checkoutLines[1].content == "Syncing repository")

    // "Get version from tag" has no content lines (only group markers)
    #expect(versionLines.isEmpty)

    // "Install XcodeGen" gets "Installing xcodegen..."
    #expect(installLines.count == 1)
    #expect(installLines[0].content == "Installing xcodegen...")
}

@Test("Sub-groups (non-Run) do not advance the step counter")
func subGroupsDoNotAdvanceStep() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run actions/checkout@v4
    2024-01-15T10:00:01.0000000Z ##[endgroup]
    2024-01-15T10:00:02.0000000Z Syncing repository
    2024-01-15T10:00:03.0000000Z ##[group]Getting Git version info
    2024-01-15T10:00:04.0000000Z ##[endgroup]
    2024-01-15T10:00:05.0000000Z git version 2.53.0
    2024-01-15T10:00:06.0000000Z ##[group]Initializing the repository
    2024-01-15T10:00:07.0000000Z ##[endgroup]
    2024-01-15T10:00:08.0000000Z Initialized empty Git repository
    """
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Checkout"),
        (3, "Next step"),
        (21, "Complete job"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)

    // All content lines should belong to step 2 (Checkout), because
    // "Getting Git version info" and "Initializing the repository" are
    // sub-groups (no "Run " prefix), not top-level step boundaries.
    for line in result {
        #expect(line.stepNumber == 2, "Expected step 2 but got \(line.stepNumber) for: \(line.content)")
    }
}

@Test("Internal steps (Set up job, Post *, Complete job) are excluded from user step mapping")
func internalStepsExcluded() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run echo hello
    2024-01-15T10:00:01.0000000Z ##[endgroup]
    2024-01-15T10:00:02.0000000Z hello
    """
    // Only one user step: "Say hello" at number 2.
    // Internal steps should be filtered from the sequential mapping.
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Say hello"),
        (3, "Post Checkout"),
        (4, "Complete job"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    // The first "Run" group maps to the first non-internal step: step 2
    #expect(result[0].stepNumber == 2)
}

@Test("Lines before the first Run group are assigned to the Set up job step")
func preRunLinesMapToSetupJob() {
    let raw = """
    2024-01-15T10:00:00.0000000Z Current runner version: '2.331.0'
    2024-01-15T10:00:01.0000000Z ##[group]Runner Image Provisioner
    2024-01-15T10:00:02.0000000Z ##[endgroup]
    2024-01-15T10:00:03.0000000Z Secret source: Actions
    2024-01-15T10:00:04.0000000Z Prepare workflow directory
    2024-01-15T10:00:05.0000000Z ##[group]Run actions/checkout@v4
    2024-01-15T10:00:06.0000000Z ##[endgroup]
    2024-01-15T10:00:07.0000000Z Syncing repository
    """
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Checkout"),
        (21, "Complete job"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)

    let setupLines = result.filter { $0.stepNumber == 1 }
    let checkoutLines = result.filter { $0.stepNumber == 2 }

    // Pre-Run lines: "Current runner version", "Secret source", "Prepare workflow directory"
    #expect(setupLines.count == 3)
    #expect(setupLines[0].content == "Current runner version: '2.331.0'")

    // Post-Run lines belong to Checkout
    #expect(checkoutLines.count == 1)
    #expect(checkoutLines[0].content == "Syncing repository")
}

@Test("When no Set up job step exists, pre-Run lines get step number 0")
func preRunLinesWithoutSetupJob() {
    let raw = """
    2024-01-15T10:00:00.0000000Z Current runner version: '2.331.0'
    2024-01-15T10:00:01.0000000Z ##[group]Run echo hi
    2024-01-15T10:00:02.0000000Z ##[endgroup]
    """
    // No "Set up job" step in the list at all
    let steps = makeSteps([
        (2, "Say hi"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    let preRunLines = result.filter { $0.stepNumber == 0 }
    #expect(preRunLines.count == 1)
}

// MARK: - Multiple Steps With Mixed Content

@Test("Mixed errors, warnings, and normal lines across multiple steps")
func mixedContentAcrossSteps() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run npm test
    2024-01-15T10:00:01.0000000Z ##[endgroup]
    2024-01-15T10:00:02.0000000Z Running tests...
    2024-01-15T10:00:03.0000000Z ##[warning]Deprecated API usage detected
    2024-01-15T10:00:04.0000000Z ##[group]Run npm run build
    2024-01-15T10:00:05.0000000Z ##[endgroup]
    2024-01-15T10:00:06.0000000Z Building...
    2024-01-15T10:00:07.0000000Z ##[error]Build failed: missing module
    """
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Test"),
        (3, "Build"),
        (4, "Complete job"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)

    let testLines = result.filter { $0.stepNumber == 2 }
    let buildLines = result.filter { $0.stepNumber == 3 }

    #expect(testLines.count == 2)
    #expect(testLines[0].content == "Running tests...")
    #expect(testLines[0].isError == false)
    #expect(testLines[1].content == "Deprecated API usage detected")
    #expect(testLines[1].isWarning == true)

    #expect(buildLines.count == 2)
    #expect(buildLines[0].content == "Building...")
    #expect(buildLines[1].content == "Build failed: missing module")
    #expect(buildLines[1].isError == true)
}

// MARK: - Real-World Log: Build Job Excerpt

@Test("Real build log: runner setup, checkout, and shell step")
func realWorldBuildLogExcerpt() {
    // Extracted from akoenig/runway Release workflow run #22672770685, build job.
    let raw = """
    2026-03-04T14:03:52.2427440Z Current runner version: '2.331.0'
    2026-03-04T14:03:52.2441420Z ##[group]Runner Image Provisioner
    2026-03-04T14:03:52.2441890Z Hosted Compute Agent
    2026-03-04T14:03:52.2442230Z Version: 20260213.493
    2026-03-04T14:03:52.2442610Z Commit: 5c115507f6dd24b8de37d8bbe0bb4509d0cc0fa3
    2026-03-04T14:03:52.2443040Z Build Date: 2026-02-13T00:28:41Z
    2026-03-04T14:03:52.2443870Z ##[endgroup]
    2026-03-04T14:03:52.2445010Z ##[group]Operating System
    2026-03-04T14:03:52.2445350Z macOS
    2026-03-04T14:03:52.2445620Z 15.7.4
    2026-03-04T14:03:52.2445890Z ##[endgroup]
    2026-03-04T14:03:52.2453400Z Secret source: Actions
    2026-03-04T14:03:52.2453800Z Prepare workflow directory
    2026-03-04T14:03:52.2807520Z Prepare all required actions
    2026-03-04T14:03:52.2839510Z Getting action download info
    2026-03-04T14:03:53.8393530Z Complete job name: build
    2026-03-04T14:03:53.8801680Z ##[group]Run actions/checkout@v4
    2026-03-04T14:03:53.8802170Z with:
    2026-03-04T14:03:53.8802440Z   fetch-depth: 0
    2026-03-04T14:03:53.8803150Z   token: ***
    2026-03-04T14:03:53.8806410Z ##[endgroup]
    2026-03-04T14:03:54.1439860Z Syncing repository: akoenig/runway
    2026-03-04T14:03:54.1441680Z ##[group]Getting Git version info
    2026-03-04T14:03:54.1442200Z Working directory is '/Users/runner/work/runway/runway'
    2026-03-04T14:03:54.1443030Z [command]/opt/homebrew/bin/git version
    2026-03-04T14:03:54.1983460Z git version 2.53.0
    2026-03-04T14:03:54.2005590Z ##[endgroup]
    2026-03-04T14:03:55.3941280Z ##[group]Run echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT
    2026-03-04T14:03:55.3942000Z \u{1B}[36;1mecho "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT\u{1B}[0m
    2026-03-04T14:03:55.3978570Z shell: /bin/bash -e {0}
    2026-03-04T14:03:55.3979020Z ##[endgroup]
    2026-03-04T14:03:55.4218240Z ##[group]Run maxim-lobanov/setup-xcode@v1
    2026-03-04T14:03:55.4218660Z   xcode-version: 26.2
    2026-03-04T14:03:55.4218960Z ##[endgroup]
    2026-03-04T14:03:55.4690760Z Switching Xcode to version '26.2'...
    2026-03-04T14:03:55.5285210Z Xcode is set to 26.2.0 (17C52)
    """

    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Checkout"),
        (3, "Get version from tag"),
        (4, "Setup Xcode"),
        (5, "Install XcodeGen"),
        (6, "Generate Xcode project"),
        (7, "Build"),
        (8, "Create archive"),
        (9, "Create DMG"),
        (10, "Upload artifact"),
        (20, "Post Checkout"),
        (21, "Complete job"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)

    // --- Set up job (step 1): lines before the first "Run" group ---
    // Note: content lines *inside* sub-groups (e.g. "Hosted Compute Agent",
    // "Version:", "macOS", etc.) are output by the parser — only the
    // ##[group]/##[endgroup] marker lines themselves are suppressed.
    let setupLines = result.filter { $0.stepNumber == 1 }
    #expect(setupLines.count == 12, "Expected 12 setup lines, got \(setupLines.count)")
    #expect(setupLines[0].content == "Current runner version: '2.331.0'")
    #expect(setupLines.contains { $0.content == "Secret source: Actions" })
    #expect(setupLines.contains { $0.content == "Complete job name: build" })

    // --- Checkout (step 2): content inside the first "Run" group + sub-groups ---
    let checkoutLines = result.filter { $0.stepNumber == 2 }
    // "with:", "  fetch-depth: 0", "  token: ***", "Syncing repository",
    // sub-group content: "Working directory...", "[command]...", "git version 2.53.0"
    #expect(checkoutLines.count == 7)
    #expect(checkoutLines[0].content == "with:")
    #expect(checkoutLines.contains { $0.content == "Syncing repository: akoenig/runway" })
    #expect(checkoutLines.contains { $0.content == "git version 2.53.0" })

    // --- Get version from tag (step 3): has ANSI codes that should be stripped ---
    let versionLines = result.filter { $0.stepNumber == 3 }
    #expect(versionLines.count == 2)
    // ANSI codes should be stripped from the echo command
    #expect(versionLines[0].content == "echo \"VERSION=${GITHUB_REF#refs/tags/v}\" >> $GITHUB_OUTPUT")
    #expect(versionLines[1].content == "shell: /bin/bash -e {0}")

    // --- Setup Xcode (step 4) ---
    let xcodeLines = result.filter { $0.stepNumber == 4 }
    #expect(xcodeLines.count == 3)
    #expect(xcodeLines[0].content == "  xcode-version: 26.2")
    #expect(xcodeLines.contains { $0.content == "Switching Xcode to version '26.2'..." })
    #expect(xcodeLines.contains { $0.content == "Xcode is set to 26.2.0 (17C52)" })

    // No errors or warnings in this excerpt
    #expect(result.allSatisfy { !$0.isError && !$0.isWarning })
}

// MARK: - Real-World Log: Release Job

@Test("Real release log: download artifact and gh-release steps")
func realWorldReleaseLogExcerpt() {
    let raw = """
    2026-03-04T14:07:01.4253760Z Current runner version: '2.331.0'
    2026-03-04T14:07:01.4270920Z ##[group]Runner Image Provisioner
    2026-03-04T14:07:01.4271430Z Hosted Compute Agent
    2026-03-04T14:07:01.4273750Z ##[endgroup]
    2026-03-04T14:07:01.4282990Z Secret source: Actions
    2026-03-04T14:07:01.4283370Z Prepare workflow directory
    2026-03-04T14:07:03.8810560Z Complete job name: release
    2026-03-04T14:07:03.9285930Z ##[group]Run actions/download-artifact@v4
    2026-03-04T14:07:03.9287750Z with:
    2026-03-04T14:07:03.9288860Z   merge-multiple: true
    2026-03-04T14:07:03.9291050Z ##[endgroup]
    2026-03-04T14:07:04.6735950Z Found 1 artifact(s)
    2026-03-04T14:07:05.7028220Z Total of 1 artifact(s) downloaded
    2026-03-04T14:07:05.7029150Z Download artifact has finished successfully
    2026-03-04T14:07:05.7193310Z ##[group]Run softprops/action-gh-release@v2
    2026-03-04T14:07:05.7193650Z with:
    2026-03-04T14:07:05.7193810Z   files: ./**/*.dmg
    2026-03-04T14:07:05.7194260Z   generate_release_notes: true
    2026-03-04T14:07:05.7195870Z ##[endgroup]
    2026-03-04T14:07:06.3200340Z Found release v1.5.0 (with id=292942562)
    2026-03-04T14:07:08.5681570Z Finalizing release...
    2026-03-04T14:07:08.9452580Z Cleaning up orphan processes
    """

    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Download artifact"),
        (3, "Release"),
        (4, "Complete job"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)

    // Setup lines (before first "Run")
    // "Hosted Compute Agent" (inside Runner Image Provisioner group) is also
    // included since only the ##[group]/##[endgroup] markers are suppressed.
    let setupLines = result.filter { $0.stepNumber == 1 }
    #expect(setupLines.count == 5)
    #expect(setupLines[0].content == "Current runner version: '2.331.0'")
    #expect(setupLines.contains { $0.content == "Complete job name: release" })

    // Download artifact step
    let downloadLines = result.filter { $0.stepNumber == 2 }
    #expect(downloadLines.count == 5)
    #expect(downloadLines[0].content == "with:")
    #expect(downloadLines.contains { $0.content == "Found 1 artifact(s)" })
    #expect(downloadLines.contains { $0.content == "Download artifact has finished successfully" })

    // Release step
    let releaseLines = result.filter { $0.stepNumber == 3 }
    #expect(releaseLines.count == 6)
    #expect(releaseLines.contains { $0.content == "Found release v1.5.0 (with id=292942562)" })
    #expect(releaseLines.contains { $0.content == "Cleaning up orphan processes" })
}

// MARK: - Edge Cases

@Test("More Run groups than user steps does not crash")
func moreRunGroupsThanSteps() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run echo first
    2024-01-15T10:00:01.0000000Z ##[endgroup]
    2024-01-15T10:00:02.0000000Z first output
    2024-01-15T10:00:03.0000000Z ##[group]Run echo second
    2024-01-15T10:00:04.0000000Z ##[endgroup]
    2024-01-15T10:00:05.0000000Z second output
    2024-01-15T10:00:06.0000000Z ##[group]Run echo third
    2024-01-15T10:00:07.0000000Z ##[endgroup]
    2024-01-15T10:00:08.0000000Z third output
    """
    // Only one user step defined, but three Run groups in the log
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "First step"),
        (21, "Complete job"),
    ])
    // Should not crash; the extra Run groups just keep the last assigned step
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(!result.isEmpty)
    #expect(result[0].stepNumber == 2)
}

@Test("Steps with no corresponding log content produce no lines for that step")
func stepWithNoLogContent() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run echo hello
    2024-01-15T10:00:01.0000000Z ##[endgroup]
    2024-01-15T10:00:02.0000000Z ##[group]Run echo world
    2024-01-15T10:00:03.0000000Z ##[endgroup]
    2024-01-15T10:00:04.0000000Z world output
    """
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Say hello"),
        (3, "Say world"),
        (4, "Complete job"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    let helloLines = result.filter { $0.stepNumber == 2 }
    let worldLines = result.filter { $0.stepNumber == 3 }
    #expect(helloLines.isEmpty, "Step 2 should have no content lines")
    #expect(worldLines.count == 1)
    #expect(worldLines[0].content == "world output")
}

@Test("Log with only group markers and no content produces empty result")
func onlyGroupMarkers() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run echo hello
    2024-01-15T10:00:01.0000000Z ##[endgroup]
    """
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Say hello"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.isEmpty)
}

@Test("BOM character at start of log is handled gracefully")
func bomCharacterHandled() {
    // Real GitHub logs sometimes start with a UTF-8 BOM (U+FEFF)
    let raw = "\u{FEFF}2024-01-15T10:00:00.0000000Z Current runner version: '2.331.0'"
    let steps = makeSteps([(1, "Set up job")])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result.count == 1)
    // The BOM may or may not be stripped by the timestamp regex;
    // the key assertion is that we get a result and don't crash.
}

@Test("Post-prefixed steps are treated as internal")
func postStepsAreInternal() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run echo first
    2024-01-15T10:00:01.0000000Z ##[endgroup]
    2024-01-15T10:00:02.0000000Z first output
    2024-01-15T10:00:03.0000000Z ##[group]Run echo second
    2024-01-15T10:00:04.0000000Z ##[endgroup]
    2024-01-15T10:00:05.0000000Z second output
    """
    let steps = makeSteps([
        (1, "Set up job"),
        (2, "Checkout"),
        (3, "Build"),
        (20, "Post Checkout"),
        (21, "Post Build"),
        (22, "Complete job"),
    ])
    // "Post Checkout" and "Post Build" should be excluded from user steps.
    // Two Run groups should map to steps 2 and 3 (the non-internal ones).
    let result = GitHubService.parseLogLines(raw, steps: steps)
    #expect(result[0].stepNumber == 2)
    #expect(result[1].stepNumber == 3)
}

@Test("Steps sorted correctly regardless of input order")
func stepsOutOfOrder() {
    let raw = """
    2024-01-15T10:00:00.0000000Z ##[group]Run echo first
    2024-01-15T10:00:01.0000000Z ##[endgroup]
    2024-01-15T10:00:02.0000000Z first
    2024-01-15T10:00:03.0000000Z ##[group]Run echo second
    2024-01-15T10:00:04.0000000Z ##[endgroup]
    2024-01-15T10:00:05.0000000Z second
    """
    // Steps provided out of order — parser should sort by number
    let steps = makeSteps([
        (1, "Set up job"),
        (5, "Step B"),
        (3, "Step A"),
        (10, "Complete job"),
    ])
    let result = GitHubService.parseLogLines(raw, steps: steps)
    // First Run group -> Step A (number 3, first non-internal sorted)
    #expect(result[0].stepNumber == 3)
    // Second Run group -> Step B (number 5)
    #expect(result[1].stepNumber == 5)
}
