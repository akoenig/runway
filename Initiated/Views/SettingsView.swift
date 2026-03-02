import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: AppViewModel
    @State private var patInput: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showToken: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("GitHub Personal Access Token")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    if showToken {
                        TextField("Enter your PAT", text: $patInput)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        SecureField("Enter your PAT", text: $patInput)
                            .textFieldStyle(.roundedBorder)
                    }

                    Button {
                        showToken.toggle()
                    } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.plain)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await connect()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 80)
                    } else {
                        Text("Connect")
                            .frame(width: 80)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(patInput.isEmpty || isLoading)
            }

            if viewModel.isAuthenticated {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Connected as \(viewModel.githubUser?.login ?? "Unknown")")
                            .font(.subheadline)
                    }

                    if let user = viewModel.githubUser, let name = user.name {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Polling Interval")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Interval", selection: $viewModel.pollingInterval) {
                    Text("15 seconds").tag(15)
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                }
                .pickerStyle(.segmented)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Quit Initiated") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 280, height: 320)
        .onAppear {
            patInput = ""
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
