import AppKit
import Foundation
import UserNotifications

final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        // Must be set early so the delegate is in place before any
        // notifications are scheduled. The delegate reference is weak,
        // but NotificationService is retained by AppDelegate for the
        // lifetime of the app.
        center.delegate = self
    }

    func requestAuthorization() {
        // Check current authorization status first. If already determined,
        // don't re-prompt — just log the state for debugging.
        center.getNotificationSettings { [weak self] settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                self?.center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error = error {
                        print("[Runway] Notification authorization error: \(error)")
                    }
                    print("[Runway] Notification authorization granted: \(granted)")
                }
            case .denied:
                print("[Runway] Notifications denied by user. Open System Settings > Notifications to enable.")
            case .authorized, .provisional, .ephemeral:
                print("[Runway] Notifications authorized")
            @unknown default:
                break
            }
        }
    }

    func sendNotification(for workflow: WorkflowRun) {
        let content = UNMutableNotificationContent()

        switch workflow.workflowStatus {
        case .success:
            content.title = "Workflow Succeeded"
        case .failure:
            content.title = "Workflow Failed"
        default:
            return
        }

        content.body = "\(workflow.name) on \(workflow.repository.displayFullName)"
        content.sound = .default
        content.categoryIdentifier = "WORKFLOW_COMPLETION"

        if let url = URL(string: workflow.htmlUrl) {
            content.userInfo = ["url": url.absoluteString]
        }

        let request = UNNotificationRequest(
            identifier: "workflow-\(workflow.id)",
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                print("[Runway] Failed to schedule notification: \(error)")
            } else {
                print("[Runway] Notification scheduled for workflow \(workflow.id): \(workflow.name)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Allow notifications to display even when the app is in the foreground.
    /// Without this, macOS silently suppresses notifications for the active app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Open the workflow URL in the browser when the user clicks the notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let urlString = userInfo["url"] as? String,
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
        completionHandler()
    }
}
