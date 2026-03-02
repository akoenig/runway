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
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSettings = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Connection Section
                    connectionSection
                    
                    // Repositories Section
                    if viewModel.isAuthenticated {
                        reposSection
                    }
                    
                    // Polling Section
                    pollingSection
                    
                    // About Section
                    aboutSection
                }
                .padding(20)
            }
        }
        .sheet(isPresented: $showRepoSelection) {
            RepoSelectionView(viewModel: viewModel)
        }
    }
    
    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "link.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 18))
                
                Text("GitHub Connection")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
            }
            
            if viewModel.isAuthenticated {
                // Connected state
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.15))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Connected")
                            .font(.system(size: 13, weight: .medium))
                        
                        if let username = viewModel.githubUser?.login {
                            Text("@\(username)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
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
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            } else {
                // Not connected state
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Personal Access Token")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            Group {
                                if showToken {
                                    TextField("ghp_...", text: $patInput)
                                } else {
                                    SecureField("ghp_...", text: $patInput)
                                }
                            }
                            .font(.system(size: 13))
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.secondary.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            
                            Button {
                                showToken.toggle()
                            } label: {
                                Image(systemName: showToken ? "eye.slash" : "eye")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(Color.secondary.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 11))
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Button {
                        Task {
                            await connect()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                                    .tint(.white)
                            } else {
                                Image(systemName: "link")
                                Text("Connect")
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(patInput.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .disabled(patInput.isEmpty || isLoading)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    private var reposSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "folder.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 18))
                
                Text("Repositories")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
                
                Text("\(viewModel.selectedRepos.count) selected")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Select which repositories to monitor for workflow runs.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Button {
                    viewModel.errorMessage = nil
                    showRepoSelection = true
                    Task {
                        await viewModel.fetchAvailableRepos()
                    }
                } label: {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Manage Repositories")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    private var pollingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.blue)
                    .font(.system(size: 18))
                
                Text("Update Frequency")
                    .font(.system(size: 14, weight: .semibold))
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach([15, 30, 60, 120], id: \.self) { interval in
                    Button {
                        viewModel.pollingInterval = interval
                    } label: {
                        HStack {
                            Text(intervalText(interval))
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if viewModel.pollingInterval == interval {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.system(size: 16))
                            } else {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                                    .frame(width: 16, height: 16)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(viewModel.pollingInterval == interval ? Color.blue.opacity(0.08) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.05))
        )
    }
    
    private var aboutSection: some View {
        VStack(spacing: 12) {
            Button {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                        .font(.system(size: 13))
                    Text("Quit Initiated")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            
            Text("Version 1.1.7")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }
    
    private func intervalText(_ interval: Int) -> String {
        switch interval {
        case 15:
            return "15 seconds"
        case 30:
            return "30 seconds"
        case 60:
            return "1 minute"
        case 120:
            return "2 minutes"
        default:
            return "\(interval) seconds"
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
                Task {
                    // Fetch repos after successful connection
                    await viewModel.fetchAvailableRepos()
                    await viewModel.fetchWorkflowRuns()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                try? KeychainService.shared.deleteToken()
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

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
                Text("Select Repositories")
                    .font(.system(size: 15, weight: .semibold))
                
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))
                
                TextField("Search repositories...", text: $searchText)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            
            // Select all/none buttons
            HStack {
                Button {
                    viewModel.selectedRepos = viewModel.availableRepos.map { $0.displayFullName }
                } label: {
                    Text("Select All")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedRepos.count == viewModel.availableRepos.count)
                
                Spacer()
                
                Button {
                    viewModel.selectedRepos = []
                } label: {
                    Text("Select None")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.selectedRepos.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Repo list
            if viewModel.isLoading && viewModel.availableRepos.isEmpty {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Spacer()
            } else if let errorMessage = viewModel.errorMessage, viewModel.availableRepos.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 36))
                        .foregroundStyle(.orange)
                    Text("Failed to load repositories")
                        .font(.system(size: 14, weight: .medium))
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    Button {
                        Task {
                            await viewModel.fetchAvailableRepos()
                        }
                    } label: {
                        Text("Retry")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            } else if viewModel.availableRepos.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.questionmark")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No repositories found")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredRepos, id: \.displayFullName) { repo in
                        Button {
                            toggleRepo(repo)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(repo.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.primary)
                                    
                                    Text(repo.owner.login)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if viewModel.selectedRepos.contains(repo.displayFullName) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                        .font(.system(size: 18))
                                } else {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1.5)
                                        .frame(width: 18, height: 18)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
                    }
                }
                .listStyle(.plain)
            }
            
            // Footer
            HStack {
                Text("\(viewModel.selectedRepos.count) of \(viewModel.availableRepos.count) selected")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    dismiss()
                    Task {
                        await viewModel.fetchWorkflowRuns()
                    }
                } label: {
                    Text("Done")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedRepos.isEmpty ? Color.blue.opacity(0.5) : Color.blue)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
        .frame(width: 400, height: 500)
    }
    
    private func toggleRepo(_ repo: Repository) {
        if viewModel.selectedRepos.contains(repo.displayFullName) {
            viewModel.selectedRepos.removeAll { $0 == repo.displayFullName }
        } else {
            viewModel.selectedRepos.append(repo.displayFullName)
        }
    }
}
