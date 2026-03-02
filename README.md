# Initiated

A native macOS menu bar app that monitors your GitHub Actions workflows. Track the status of your workflows directly from the menu bar with beautiful color-coded indicators and native notifications.

![Platform](https://img.shields.io/badge/platform-macOS%2014+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu Bar Integration** - Minimal, non-intrusive indicator in your menu bar
- **Color-Coded Status** - Instantly see workflow status at a glance
  - 🟠 Orange: Running
  - 🔴 Red: Failed
  - 🟢 Green: Succeeded
  - ⚪ Gray: Idle
- **Native Notifications** - Get notified when workflows complete (success or failure)
- **One-Click Access** - Click any workflow to open it in GitHub
- **Frictionless Setup** - Just enter your GitHub PAT, everything else is automatic

## Requirements

- macOS 14.0 or later
- A GitHub account
- A GitHub Personal Access Token (PAT)

## Installation

### From Source

1. Clone the repository:
   ```bash
   git clone https://github.com/akoenig/initiated.git
   cd initiated
   ```

2. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```

3. Open in Xcode:
   ```bash
   open Initiated.xcodeproj
   ```

4. Build and run (Cmd+R)

## Setting Up GitHub Personal Access Token

To use Initiated, you need a GitHub Personal Access Token (PAT) with the following scopes:

### Required Scopes

1. **`repo`** - Full control of repositories
   - Required to access workflow runs
2. **`workflow`** - Update GitHub Actions workflows
   - Required to read workflow run data

### Creating a PAT

1. Go to [GitHub Settings → Personal access tokens → Tokens (classic)](https://github.com/settings/tokens)
2. Click "Generate new token (classic)"
3. Give it a descriptive name (e.g., "Initiated macOS App")
4. Select the following scopes:
   - ☑️ `repo` (Full control of private repositories)
   - ☑️ `workflow` (Update GitHub Action workflows)
5. Click "Generate token"
6. **Important**: Copy the token immediately - you won't be able to see it again!

### Security Note

Your PAT is stored securely in the macOS Keychain, not in plain text. The app only uses the token to read workflow data - it cannot modify your repositories.

## Usage

1. **Launch the app** - Initiated appears as a dot in your menu bar (no Dock icon)
2. **Click the menu bar icon** - Opens the main popover
3. **Click the gear icon** - Opens Settings
4. **Enter your PAT** - Click "Connect" to authenticate
5. **You're done!** - Your workflows will appear automatically

### Menu Bar Icon Behavior

| Status | Color | Description |
|--------|-------|-------------|
| Running | Orange | At least one workflow is running |
| Failed | Red | A workflow has failed |
| Success | Green | All recent workflows succeeded (none running) |
| Idle | Gray | No workflows found or not connected |

### Popover Interface

- **Header**: App name + settings gear icon
- **Workflow List**: Shows your 10 most recent workflow runs
- **Click a workflow**: Opens it in GitHub
- **Footer**: Status text + refresh button

### Notifications

You'll receive a native macOS notification when:
- A workflow completes successfully
- A workflow fails

Clicking the notification opens the workflow in GitHub.

## Preferences

Customize Initiated via the Settings popover:

- **GitHub PAT**: Your authentication token
- **Polling Interval**: How often to check for updates (15s, 30s, 1m, 2m)
- **Quit**: Exit the application

## Architecture

Initiated is built with modern macOS development practices:

- **SwiftUI** for all UI components
- **AppKit** for menu bar integration
- **MVVM** architecture with `@Observable`
- **Async/await** for all network operations
- **Keychain** for secure token storage

### Project Structure

```
Initiated/
├── App/
│   ├── InitiatedApp.swift       # SwiftUI App entry point
│   └── AppDelegate.swift        # Menu bar setup & management
├── Models/
│   ├── WorkflowRun.swift        # Workflow data model
│   └── GitHubUser.swift         # GitHub user model
├── Services/
│   ├── GitHubService.swift      # GitHub API client
│   ├── KeychainService.swift    # Secure token storage
│   └── NotificationService.swift # macOS notifications
├── ViewModels/
│   └── AppViewModel.swift       # Main application state
└── Views/
    ├── MenuBarView.swift        # Main popover content
    ├── WorkflowRowView.swift    # Individual workflow row
    └── SettingsView.swift       # Settings/connection view
```

## Troubleshooting

### "Failed to connect" error

- Make sure your PAT has the required scopes (`repo` and `workflow`)
- Check your internet connection
- Verify the PAT hasn't expired

### No workflows appearing

- Ensure your GitHub account has triggered workflow runs
- Check that the PAT is properly saved (try reconnecting)
- Verify the polling interval isn't too long

### Notifications not working

- Check System Settings → Notifications → Allow Initiated
- Make sure notifications are enabled in the app

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

MIT License - see LICENSE file for details.

---

Built with ❤️ for macOS developers
