import AppKit
import SwiftUI

struct SettingsView: View {
    var viewModel: AppViewModel
    @Binding var showSettings: Bool
    @State private var patInput: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showToken: Bool = false
    @State private var showRepoSelection: Bool = false
    @State private var shortcutRecorder = ShortcutRecorder()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    connectionSection
                    if viewModel.isAuthenticated {
                        reposSection
                    }
                    pollingSection
                    shortcutSection
                    loginItemSection
                    quitSection
                }
                .padding(.vertical, 8)
            }

            Divider().opacity(0.3)
            footerBar
        }
        .sheet(isPresented: $showRepoSelection) {
            RepoSelectionView(viewModel: viewModel)
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "GitHub", description: "Connect your account to start monitoring CI workflows.")

            if viewModel.isAuthenticated {
                connectedRow
            } else {
                tokenInputSection
            }
        }
    }

    private var connectedRow: some View {
        HStack(spacing: 12) {
            // GitHub profile image with fallback to initial letter
            if let avatarUrlString = viewModel.githubUser?.avatarUrl,
               let avatarUrl = URL(string: avatarUrlString) {
                AsyncImage(url: avatarUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                    default:
                        avatarFallback
                    }
                }
                .frame(width: 32, height: 32)
            } else {
                avatarFallback
            }

            VStack(alignment: .leading, spacing: 2) {
                if let login = viewModel.githubUser?.login {
                    Text(login)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text("Connected")
                    .font(.system(size: 11))
                    .foregroundStyle(.green)
            }

            Spacer()

            Button {
                viewModel.disconnect()
            } label: {
                Text("Disconnect")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var avatarFallback: some View {
        ZStack {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 32, height: 32)

            Text(String((viewModel.githubUser?.login ?? "?").prefix(1)).uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
        }
    }

    private var tokenInputSection: some View {
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
                        Text("Connect")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(patInput.isEmpty ? Color.accentColor.opacity(0.4) : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
            .disabled(patInput.isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    // MARK: - Repositories

    private var reposSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "Repositories", description: "Choose which repositories Runway watches for workflow runs.")

            Button {
                viewModel.errorMessage = nil
                showRepoSelection = true
                Task {
                    await viewModel.fetchAvailableRepos()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 32, height: 32)

                        Image(systemName: "folder")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(viewModel.selectedRepos.count) monitored")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)

                        Text("Tap to manage")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Polling

    private var pollingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "Update Frequency", description: "How often Runway polls GitHub for new workflow results.")

            HStack(spacing: 4) {
                ForEach([15, 30, 60, 120], id: \.self) { interval in
                    Button {
                        viewModel.pollingInterval = interval
                    } label: {
                        Text(shortInterval(interval))
                            .font(.system(size: 12, weight: viewModel.pollingInterval == interval ? .semibold : .regular))
                            .foregroundStyle(viewModel.pollingInterval == interval ? .white : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(viewModel.pollingInterval == interval ? Color.accentColor : Color.primary.opacity(0.04))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Keyboard Shortcut

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "Keyboard Shortcut", description: "Open Runway from anywhere on your Mac with a global hotkey.")

            HStack {
                if shortcutRecorder.isRecording {
                    Text("Press a key combination...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        shortcutRecorder.stopRecording()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                } else if viewModel.shortcutKeyCode >= 0 {
                    Text(viewModel.shortcutDisplayString)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 5))

                    Spacer()

                    Button {
                        shortcutRecorder.startRecording { keyCode, flags, displayChar in
                            viewModel.setShortcut(
                                keyCode: Int(keyCode),
                                modifiers: Int(flags.rawValue),
                                keyChar: displayChar
                            )
                        }
                    } label: {
                        Text("Change")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.clearShortcut()
                    } label: {
                        Text("Clear")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        shortcutRecorder.startRecording { keyCode, flags, displayChar in
                            viewModel.setShortcut(
                                keyCode: Int(keyCode),
                                modifiers: Int(flags.rawValue),
                                keyChar: displayChar
                            )
                        }
                    } label: {
                        Text("Record Shortcut")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Login Item

    private var loginItemSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader(title: "General", description: "System-level preferences for how Runway behaves on startup.")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start at Login")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("Launch Runway automatically when you log in")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { LoginItemService.shared.isEnabled },
                    set: { _ in
                        try? LoginItemService.shared.toggle()
                    }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Quit

    private var quitSection: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.2).padding(.horizontal, 16)

            Button {
                NSApp.terminate(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "power")
                        .font(.system(size: 11))
                    Text("Quit Runway")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 8)
    }

    // MARK: - Footer Bar

    private var footerBar: some View {
        HStack {
            Button {
                showSettings = false
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.system(size: 11))
                .foregroundStyle(.quaternary)

            Spacer()

            Button {
                NSWorkspace.shared.open(URL(string: "https://github.com/anomalyco/Runway")!)
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.quaternary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("View on GitHub")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Shared Components

    private func sectionHeader(title: String, description: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)

            if let description {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 6)
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
            try await viewModel.connect(token: patInput)
            isLoading = false
            showSettings = false
        } catch {
            errorMessage = error.localizedDescription
            try? KeychainService.shared.deleteToken()
            isLoading = false
        }
    }
}
