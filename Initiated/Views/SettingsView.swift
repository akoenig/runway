import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var showSettings: Bool
    @State private var patInput: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showToken: Bool = false
    @State private var showRepoSelection: Bool = false
    @StateObject private var shortcutRecorder = ShortcutRecorder()

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
            sectionHeader(title: "GitHub")

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
            sectionHeader(title: "Repositories")

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
            sectionHeader(title: "Update Frequency")

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
            sectionHeader(title: "Keyboard Shortcut")

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
            sectionHeader(title: "General")

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start at Login")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("Launch Initiated automatically when you log in")
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
                    Text("Quit Initiated")
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

            // Invisible spacer to balance the back button
            Color.clear.frame(width: 28, height: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Shared Components

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.primary)
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
            try KeychainService.shared.saveToken(patInput)
            let user = try await GitHubService.shared.validateToken()

            await MainActor.run {
                viewModel.githubUser = user
                viewModel.isAuthenticated = true
                viewModel.saveSettings()
                isLoading = false
                showSettings = false
            }

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
                    .font(.system(size: 15, weight: .bold))

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                        .background(Color.primary.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

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
            .padding(.bottom, 10)

            Divider().opacity(0.3)

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
            .padding(.vertical, 8)

            Divider().opacity(0.2)

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
                        .padding(.horizontal, 20)
                        .padding(.vertical, 7)
                        .background(viewModel.selectedRepos.isEmpty ? Color.accentColor.opacity(0.4) : Color.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
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
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(repo.name)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.primary)

                                Text(repo.owner?.login ?? "unknown")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }

                            Spacer()

                            if viewModel.selectedRepos.contains(repo.displayFullName) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                                    .font(.system(size: 18))
                            } else {
                                Circle()
                                    .stroke(Color.primary.opacity(0.12), lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
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

// MARK: - Shortcut Recorder

final class ShortcutRecorder: ObservableObject {
    @Published var isRecording: Bool = false

    private var monitor: Any?
    private var completion: ((UInt16, NSEvent.ModifierFlags, String) -> Void)?

    func startRecording(completion: @escaping (UInt16, NSEvent.ModifierFlags, String) -> Void) {
        self.completion = completion
        isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }

            // Escape cancels recording
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }

            // Require at least one modifier (Cmd, Opt, Ctrl, Shift)
            let required: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
            guard !event.modifierFlags.intersection(required).isEmpty else {
                return nil
            }

            let displayChar = Self.displayString(for: event.keyCode, characters: event.charactersIgnoringModifiers)
            self.completion?(event.keyCode, event.modifierFlags.intersection(required), displayChar)
            self.stopRecording()
            return nil
        }
    }

    func stopRecording() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        isRecording = false
        completion = nil
    }

    deinit {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Key Display Names

    private static func displayString(for keyCode: UInt16, characters: String?) -> String {
        switch keyCode {
        case 36: return "\u{21A9}"     // Return
        case 48: return "\u{21E5}"     // Tab
        case 49: return "Space"
        case 51: return "\u{232B}"     // Delete
        case 53: return "\u{238B}"     // Escape
        case 76: return "\u{2324}"     // Enter (numpad)
        case 123: return "\u{2190}"
        case 124: return "\u{2192}"
        case 125: return "\u{2193}"
        case 126: return "\u{2191}"
        // F-keys
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            return characters?.uppercased() ?? "?"
        }
    }
}
