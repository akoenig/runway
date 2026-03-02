import Foundation
import AppKit
import Combine

final class AppViewModel: ObservableObject {
    @Published var workflows: [WorkflowRun] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var githubUser: GitHubUser?
    @Published var isAuthenticated: Bool = false
    @Published var pollingInterval: Int = 30 {
        didSet {
            UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval")
            restartPolling()
        }
    }
    @Published var selectedRepos: [String] = [] {
        didSet {
            UserDefaults.standard.set(selectedRepos, forKey: "selectedRepos")
        }
    }
    @Published var availableRepos: [Repository] = []

    @Published var shortcutKeyCode: Int = -1
    @Published var shortcutModifiers: Int = 0
    @Published var shortcutKeyChar: String = ""

    var onWorkflowCompleted: ((WorkflowRun) -> Void)?
    var onShortcutChanged: (() -> Void)?

    private var monitoringTask: Task<Void, Never>?
    private var previousCompletedWorkflowIds: Set<Int> = []
    /// True until the first successful fetch completes. The first fetch seeds
    /// `previousCompletedWorkflowIds` without firing notifications so the user
    /// isn't spammed with stale completions on every launch.
    private var isFirstFetch: Bool = true

    /// Tracks the in-flight user validation so startMonitoring() can await it.
    private var userValidationTask: Task<Void, Never>?

    var overallStatus: WorkflowStatus {
        guard isAuthenticated else { return .idle }

        let runningCount = workflows.filter { $0.workflowStatus == .running }.count
        let failedCount = workflows.filter { $0.workflowStatus == .failure }.count
        let successCount = workflows.filter { $0.workflowStatus == .success }.count

        // Running takes priority — active work is the most important signal.
        if runningCount > 0 {
            return .running
        } else if failedCount > 0 {
            return .failure
        } else if successCount > 0 {
            return .success
        }
        return .idle
    }

    var statusText: String {
        let runningCount = workflows.filter { $0.workflowStatus == .running }.count

        if runningCount > 0 {
            return "\(runningCount) running"
        }
        return "All clear"
    }

    init() {
        let stored = UserDefaults.standard.integer(forKey: "pollingInterval")
        if stored > 0 {
            pollingInterval = stored
        }

        if let repos = UserDefaults.standard.array(forKey: "selectedRepos") as? [String] {
            selectedRepos = repos
        }

        shortcutKeyCode = UserDefaults.standard.object(forKey: "shortcutKeyCode") as? Int ?? -1
        shortcutModifiers = UserDefaults.standard.integer(forKey: "shortcutModifiers")
        shortcutKeyChar = UserDefaults.standard.string(forKey: "shortcutKeyChar") ?? ""

        loadSavedSettings()
    }

    private func loadSavedSettings() {
        if KeychainService.shared.hasToken {
            isAuthenticated = true

            userValidationTask = Task { @MainActor in
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

    func saveSettings() {
        UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval")
        UserDefaults.standard.set(selectedRepos, forKey: "selectedRepos")
    }

    func startMonitoring() async {
        // Wait for any in-flight user validation to finish first.
        // Without this, the guard below races with loadSavedSettings()
        // and almost always fails on launch, leaving polling dead.
        if let validationTask = userValidationTask {
            await validationTask.value
        }

        guard isAuthenticated, githubUser != nil else { return }

        // Auto-select all repos on first launch so the user immediately
        // sees workflows without having to configure anything.
        if selectedRepos.isEmpty {
            await fetchAvailableRepos()
        }

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
                try? await Task.sleep(nanoseconds: UInt64(pollingInterval) * 1_000_000_000)
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

    @MainActor
    func fetchAvailableRepos() async {
        isLoading = true
        errorMessage = nil

        do {
            let repos = try await GitHubService.shared.fetchUserRepos(perPage: 100)
            availableRepos = repos.sorted { $0.displayFullName < $1.displayFullName }

            // If no repos selected yet, select all by default (frictionless)
            if selectedRepos.isEmpty {
                selectedRepos = repos.map { $0.displayFullName }
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    @MainActor
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
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    // MARK: - Keyboard Shortcut

    func setShortcut(keyCode: Int, modifiers: Int, keyChar: String) {
        shortcutKeyCode = keyCode
        shortcutModifiers = modifiers
        shortcutKeyChar = keyChar
        UserDefaults.standard.set(keyCode, forKey: "shortcutKeyCode")
        UserDefaults.standard.set(modifiers, forKey: "shortcutModifiers")
        UserDefaults.standard.set(keyChar, forKey: "shortcutKeyChar")
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
