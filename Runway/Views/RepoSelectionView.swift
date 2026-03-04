import SwiftUI

struct RepoSelectionView: View {
    var viewModel: AppViewModel
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
