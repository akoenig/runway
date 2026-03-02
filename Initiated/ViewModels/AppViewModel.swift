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

    var onWorkflowCompleted: ((WorkflowRun) -> Void)?

    private var monitoringTask: Task<Void, Never>?
    private var previousCompletedWorkflowIds: Set<Int> = []

    var overallStatus: WorkflowStatus {
        guard isAuthenticated else { return .idle }

        let runningCount = workflows.filter { $0.workflowStatus == .running }.count
        let failedCount = workflows.filter { $0.workflowStatus == .failure }.count
        let successCount = workflows.filter { $0.workflowStatus == .success }.count

        if failedCount > 0 {
            return .failure
        } else if runningCount > 0 {
            return .running
        } else if successCount > 0 {
            return .success
        }
        return .idle
    }

    var statusText: String {
        let runningCount = workflows.filter { $0.workflowStatus == .running }.count

        if runningCount > 0 {
            return "\(runningCount) workflow\(runningCount == 1 ? "" : "s") running"
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

        loadSavedSettings()
    }

    private func loadSavedSettings() {
        if KeychainService.shared.hasToken {
            isAuthenticated = true

            Task { @MainActor in
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
                await fetchWorkflowRuns()
                try? await Task.sleep(nanoseconds: UInt64(pollingInterval) * 1_000_000_000)
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
            availableRepos = repos.sorted { $0.fullName < $1.fullName }
            
            // If no repos selected yet, select all by default (frictionless)
            if selectedRepos.isEmpty {
                selectedRepos = repos.map { $0.fullName }
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
            let newlyCompleted = currentCompletedIds.subtracting(previousCompletedWorkflowIds)

            for completedId in newlyCompleted {
                if let workflow = runs.first(where: { $0.id == completedId }) {
                    onWorkflowCompleted?(workflow)
                }
            }

            previousCompletedWorkflowIds = currentCompletedIds

            self.workflows = runs
            self.isLoading = false
            updateStatusIcon()
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }

    @MainActor
    private func updateStatusIcon() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.updateStatusIcon(status: overallStatus)
    }
}
