import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var showSettings: Bool
    @State private var patInput: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showToken: Bool = false
    @State private var showRepoSelection: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider().opacity(0.4)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    connectionSection
                    if viewModel.isAuthenticated {
                        reposSection
                    }
                    pollingSection
                    footerSection
                }
                .padding(14)
            }
        }
        .sheet(isPresented: $showRepoSelection) {
            RepoSelectionView(viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showSettings = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Connection

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("GitHub", systemImage: "link")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            if viewModel.isAuthenticated {
                connectedCard
            } else {
                tokenInputCard
            }
        }
    }

    private var connectedCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                if let login = viewModel.githubUser?.login {
                    Text("@\(login)")
                        .font(.system(size: 12, weight: .medium))
                }
                Text("Connected")
                    .font(.system(size: 10))
                    .foregroundStyle(.green)
            }

            Spacer()

            Button {
                Task {
                    try? KeychainService.shared.deleteToken()
                    await MainActor.run {
                        viewModel.isAuthenticated = false
                        viewModel.githubUser = nil
                        viewModel.workflows = []
                        viewModel.selectedRepos = []
                        viewModel.availableRepos = []
                    }
                }
            } label: {
                Text("Disconnect")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var tokenInputCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                Group {
                    if showToken {
                        TextField("ghp_...", text: $patInput)
                    } else {
                        SecureField("ghp_...", text: $patInput)
                    }
                }
                .font(.system(size: 12, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                Button {
                    showToken.toggle()
                } label: {
                    Image(systemName: showToken ? "eye.slash" : "eye")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                Task { await connect() }
            } label: {
                HStack(spacing: 5) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    } else {
                        Image(systemName: "link")
                            .font(.system(size: 10))
                        Text("Connect")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(patInput.isEmpty ? Color.accentColor.opacity(0.4) : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(patInput.isEmpty || isLoading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
    }

    // MARK: - Repositories

    private var reposSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Repositories", systemImage: "folder")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            HStack {
                Text("\(viewModel.selectedRepos.count) monitored")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    viewModel.errorMessage = nil
                    showRepoSelection = true
                    Task {
                        await viewModel.fetchAvailableRepos()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Manage")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.primary.opacity(0.03))
            )
        }
    }

    // MARK: - Polling

    private var pollingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Update Frequency", systemImage: "clock.arrow.circlepath")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach([15, 30, 60, 120], id: \.self) { interval in
                    Button {
                        viewModel.pollingInterval = interval
                    } label: {
                        Text(shortInterval(interval))
                            .font(.system(size: 11, weight: viewModel.pollingInterval == interval ? .semibold : .regular))
                            .foregroundStyle(viewModel.pollingInterval == interval ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(viewModel.pollingInterval == interval ? Color.accentColor : Color.primary.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        VStack(spacing: 10) {
            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "power")
                        .font(.system(size: 10))
                    Text("Quit Initiated")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)

            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - Helpers

    private func shortInterval(_ interval: Int) -> String {
        switch interval {
        case 15: return "15s"
        case 30: return "30s"
        case 60: return "1m"
        case 120: return "2m"
        default: return "\(interval)s"
        }
    }

    private func connect() async {
        isLoading = true
        errorMessage = nil

        do {
            try KeychainService.shared.saveToken(patInput)
            let user = try await GitHubService.shared.validateToken()

            await MainActor.run {
                viewModel.githubUser = user
                viewModel.isAuthenticated = true
                viewModel.saveSettings()
                isLoading = false
                withAnimation(.easeInOut(duration: 0.15)) {
                    showSettings = false
                }
            }

            // Start monitoring in background — the main view will show
            // a loading state until workflows arrive.
            await viewModel.startMonitoring()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                try? KeychainService.shared.deleteToken()
                isLoading = false
            }
        }
    }
}

// MARK: - Repo Selection Sheet

struct RepoSelectionView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var filteredRepos: [Repository] {
        if searchText.isEmpty {
            return viewModel.availableRepos
        }
        return viewModel.availableRepos.filter { $0.displayFullName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Repositories")
                    .font(.system(size: 13, weight: .semibold))

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().opacity(0.4)

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 12))

                TextField("Search...", text: $searchText)
                    .font(.system(size: 12))
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Bulk actions
            HStack {
                Button {
                    viewModel.selectedRepos = viewModel.availableRepos.map { $0.displayFullName }
                } label: {
                    Text("All")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedRepos.count == viewModel.availableRepos.count)

                Text("\u{00B7}")
                    .foregroundStyle(.quaternary)

                Button {
                    viewModel.selectedRepos = []
                } label: {
                    Text("None")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedRepos.isEmpty)

                Spacer()

                Text("\(viewModel.selectedRepos.count)/\(viewModel.availableRepos.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider().opacity(0.3)

            // List
            repoListContent
            
            Divider().opacity(0.3)

            // Done
            HStack {
                Spacer()

                Button {
                    dismiss()
                    Task {
                        await viewModel.fetchWorkflowRuns()
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(viewModel.selectedRepos.isEmpty ? Color.accentColor.opacity(0.4) : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 360, height: 440)
    }

    @ViewBuilder
    private var repoListContent: some View {
        if viewModel.isLoading && viewModel.availableRepos.isEmpty {
            Spacer()
            VStack(spacing: 8) {
                ProgressView().scaleEffect(0.8)
                Text("Loading...")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        } else if let errorMessage = viewModel.errorMessage, viewModel.availableRepos.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Button {
                    Task { await viewModel.fetchAvailableRepos() }
                } label: {
                    Text("Retry")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        } else if viewModel.availableRepos.isEmpty {
            Spacer()
            Text("No repositories found")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer()
        } else {
            List {
                ForEach(filteredRepos, id: \.displayFullName) { repo in
                    Button { toggleRepo(repo) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(repo.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.primary)

                                Text(repo.owner?.login ?? "unknown")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            if viewModel.selectedRepos.contains(repo.displayFullName) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.system(size: 16))
                            } else {
                                Circle()
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
            .listStyle(.plain)
        }
    }

    private func toggleRepo(_ repo: Repository) {
        if viewModel.selectedRepos.contains(repo.displayFullName) {
            viewModel.selectedRepos.removeAll { $0 == repo.displayFullName }
        } else {
            viewModel.selectedRepos.append(repo.displayFullName)
        }
    }
}
