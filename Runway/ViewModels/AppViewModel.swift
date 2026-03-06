import Foundation
import AppKit

// MARK: - UserDefaults Keys

private enum DefaultsKey {
    static let pollingInterval = "pollingInterval"
    static let selectedRepos = "selectedRepos"
    static let shortcutKeyCode = "shortcutKeyCode"
    static let shortcutModifiers = "shortcutModifiers"
    static let shortcutKeyChar = "shortcutKeyChar"
}

@Observable
@MainActor
final class AppViewModel {
    var workflows: [WorkflowRun] = []
    var isLoading: Bool = false
    var errorMessage: String?
    var githubUser: GitHubUser?
    var isAuthenticated: Bool = false
    var pollingInterval: Int = 30 {
        didSet {
            UserDefaults.standard.set(pollingInterval, forKey: DefaultsKey.pollingInterval)
            restartPolling()
        }
    }
    var selectedRepos: [String] = [] {
        didSet {
            UserDefaults.standard.set(selectedRepos, forKey: DefaultsKey.selectedRepos)
        }
    }
    var availableRepos: [Repository] = []

    var shortcutKeyCode: Int = -1
    var shortcutModifiers: Int = 0
    var shortcutKeyChar: String = ""

    var onWorkflowCompleted: ((WorkflowRun) -> Void)?
    var onShortcutChanged: (() -> Void)?
    /// Set to true by MenuBarView when a sub-view (detail or settings) is active.
    var isShowingSubview: Bool = false
    /// Called by AppDelegate's hotkey handler to navigate back to the workflow list.
    var onNavigateToMainList: (() -> Void)?

    private var monitoringTask: Task<Void, Never>?
    private var previousCompletedWorkflowIds: Set<Int> = []
    /// True until the first successful fetch completes. The first fetch seeds
    /// `previousCompletedWorkflowIds` without firing notifications so the user
    /// isn't spammed with stale completions on every launch.
    private var isFirstFetch: Bool = true

    /// Tracks the in-flight user validation so startMonitoring() can await it.
    private var userValidationTask: Task<Void, Never>?

    /// Number of consecutive polling failures. Used for exponential backoff.
    private var consecutiveFailures: Int = 0

    /// Workflows updated within the last 10 minutes are considered "recent"
    /// and contribute to the overall status. Older workflows are ignored so
    /// the menu bar dot doesn't stay red/green for days after a stale run.
    private static let stalenessThreshold: TimeInterval = 10 * 60

    private var recentWorkflows: [WorkflowRun] {
        let cutoff = Date().addingTimeInterval(-Self.stalenessThreshold)
        return workflows.filter { $0.updatedAt > cutoff }
    }

    var overallStatus: WorkflowStatus {
        guard isAuthenticated else { return .idle }

        let recent = recentWorkflows
        let runningCount = recent.filter { $0.workflowStatus == .running }.count
        let failedCount = recent.filter { $0.workflowStatus == .failure }.count
        let queuedCount = recent.filter { $0.workflowStatus == .queued }.count
        let successCount = recent.filter { $0.workflowStatus == .success }.count

        // Running takes priority — active work is the most important signal.
        if runningCount > 0 {
            return .running
        } else if failedCount > 0 {
            return .failure
        } else if queuedCount > 0 {
            return .queued
        } else if successCount > 0 {
            return .success
        }
        return .idle
    }

    /// Count shown next to the menu bar dot — running and queued workflows.
    var activeWorkflowCount: Int {
        workflows.filter { $0.workflowStatus == .running || $0.workflowStatus == .queued }.count
    }

    var statusText: String {
        let runningCount = workflows.filter { $0.workflowStatus == .running }.count
        let queuedCount = workflows.filter { $0.workflowStatus == .queued }.count

        if runningCount > 0 {
            return "\(runningCount) running"
        } else if queuedCount > 0 {
            return "\(queuedCount) queued"
        }
        return "All clear"
    }

    init() {
        let stored = UserDefaults.standard.integer(forKey: DefaultsKey.pollingInterval)
        if stored > 0 {
            pollingInterval = stored
        }

        if let repos = UserDefaults.standard.array(forKey: DefaultsKey.selectedRepos) as? [String] {
            selectedRepos = repos
        }

        shortcutKeyCode = UserDefaults.standard.object(forKey: DefaultsKey.shortcutKeyCode) as? Int ?? -1
        shortcutModifiers = UserDefaults.standard.integer(forKey: DefaultsKey.shortcutModifiers)
        shortcutKeyChar = UserDefaults.standard.string(forKey: DefaultsKey.shortcutKeyChar) ?? ""

        loadSavedSettings()
    }

    private func loadSavedSettings() {
        if KeychainService.shared.hasToken {
            isAuthenticated = true

            userValidationTask = Task {
                do {
                    let user = try await GitHubService.shared.validateToken()
                    githubUser = user
                } catch {
                    try? KeychainService.shared.deleteToken()
                    isAuthenticated = false
                }
            }
        }
    }

    // MARK: - Authentication

    /// Connects to GitHub by saving the token and validating it.
    func connect(token: String) async throws {
        try KeychainService.shared.saveToken(token)
        let user = try await GitHubService.shared.validateToken()

        githubUser = user
        isAuthenticated = true
        saveSettings()

        await startMonitoring()
    }

    /// Disconnects from GitHub by removing the token and clearing all state.
    func disconnect() {
        try? KeychainService.shared.deleteToken()
        isAuthenticated = false
        githubUser = nil
        workflows = []
        selectedRepos = []
        availableRepos = []
        stopMonitoring()
    }

    func saveSettings() {
        UserDefaults.standard.set(pollingInterval, forKey: DefaultsKey.pollingInterval)
        UserDefaults.standard.set(selectedRepos, forKey: DefaultsKey.selectedRepos)
    }

    // MARK: - Monitoring

    func startMonitoring() async {
        // Wait for any in-flight user validation to finish first.
        // Without this, the guard below races with loadSavedSettings()
        // and almost always fails on launch, leaving polling dead.
        if let validationTask = userValidationTask {
            await validationTask.value
        }

        guard isAuthenticated, githubUser != nil else { return }

        await fetchWorkflowRuns()
        startPolling()
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }

    private func startPolling() {
        monitoringTask?.cancel()

        monitoringTask = Task {
            while !Task.isCancelled {
                // Sleep first — the initial fetch already happened in startMonitoring().
                // Apply exponential backoff on consecutive failures (max 5 min).
                let backoff = min(consecutiveFailures * consecutiveFailures * 5, 300)
                let sleepSeconds = UInt64(pollingInterval + backoff)
                try? await Task.sleep(nanoseconds: sleepSeconds * 1_000_000_000)
                guard !Task.isCancelled else { break }
                await fetchWorkflowRuns()
            }
        }
    }

    private func restartPolling() {
        if isAuthenticated {
            startPolling()
        }
    }

    func fetchAvailableRepos() async {
        isLoading = true
        errorMessage = nil

        do {
            // Invalidate the cached repo list so the next poll also picks up
            // any newly added/removed repositories.
            GitHubService.shared.invalidateRepoCache()

            let repos = try await GitHubService.shared.fetchUserRepos(perPage: 100)
            availableRepos = repos.sorted { $0.displayFullName < $1.displayFullName }
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func fetchWorkflowRuns() async {
        guard !selectedRepos.isEmpty else {
            workflows = []
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let runs = try await GitHubService.shared.fetchWorkflowRuns(forSelectedRepos: selectedRepos, maxRuns: 10)

            let currentCompletedIds = Set(runs.filter { $0.workflowStatus == .failure || $0.workflowStatus == .success }.map { $0.id })

            if isFirstFetch {
                // Seed the set on first fetch — don't notify for pre-existing completions.
                isFirstFetch = false
            } else {
                let newlyCompleted = currentCompletedIds.subtracting(previousCompletedWorkflowIds)
                for completedId in newlyCompleted {
                    if let workflow = runs.first(where: { $0.id == completedId }) {
                        onWorkflowCompleted?(workflow)
                    }
                }
            }

            previousCompletedWorkflowIds = currentCompletedIds

            self.workflows = runs
            self.isLoading = false
            self.consecutiveFailures = 0
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
            self.consecutiveFailures += 1
        }
    }

    // MARK: - Keyboard Shortcut

    func setShortcut(keyCode: Int, modifiers: Int, keyChar: String) {
        shortcutKeyCode = keyCode
        shortcutModifiers = modifiers
        shortcutKeyChar = keyChar
        UserDefaults.standard.set(keyCode, forKey: DefaultsKey.shortcutKeyCode)
        UserDefaults.standard.set(modifiers, forKey: DefaultsKey.shortcutModifiers)
        UserDefaults.standard.set(keyChar, forKey: DefaultsKey.shortcutKeyChar)
        onShortcutChanged?()
    }

    func clearShortcut() {
        setShortcut(keyCode: -1, modifiers: 0, keyChar: "")
    }

    var shortcutDisplayString: String {
        guard shortcutKeyCode >= 0 else { return "" }
        var s = ""
        let flags = NSEvent.ModifierFlags(rawValue: UInt(shortcutModifiers))
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        s += shortcutKeyChar
        return s
    }
}
