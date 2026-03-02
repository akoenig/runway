import Foundation
import AppKit

@MainActor
final class AppViewModel: ObservableObject {
    @Published var workflows: [WorkflowRun] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var githubUser: GitHubUser?
    @Published var isAuthenticated: Bool = false
    @Published var pollingInterval: Int {
        didSet {
            UserDefaults.standard.set(pollingInterval, forKey: "pollingInterval")
            restartPolling()
        }
    }

    var onWorkflowCompleted: ((WorkflowRun) -> Void)?

    private var monitoringTask: Task<Void, Never>?
    private var previousWorkflowIds: Set<Int> = []
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
        self.pollingInterval = UserDefaults.standard.integer(forKey: "pollingInterval")
        if pollingInterval == 0 {
            pollingInterval = 30
        }

        loadSavedSettings()
    }

    private func loadSavedSettings() {
        if KeychainService.shared.hasToken {
            isAuthenticated = true

            Task {
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
    }

    func startMonitoring() async {
        guard isAuthenticated, let user = githubUser else { return }

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

    func fetchWorkflowRuns() async {
        guard let user = githubUser else { return }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let runs = try await GitHubService.shared.fetchWorkflowRuns(actor: user.login)

            let currentCompletedIds = Set(runs.filter { $0.workflowStatus == .failure || $0.workflowStatus == .success }.map { $0.id })
            let newlyCompleted = currentCompletedIds.subtracting(previousCompletedWorkflowIds)

            for completedId in newlyCompleted {
                if let workflow = runs.first(where: { $0.id == completedId }) {
                    onWorkflowCompleted?(workflow)
                }
            }

            previousCompletedWorkflowIds = currentCompletedIds

            await MainActor.run {
                self.workflows = runs
                self.isLoading = false
                updateStatusIcon()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    private func updateStatusIcon() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.updateStatusIcon(status: overallStatus)
    }
}
