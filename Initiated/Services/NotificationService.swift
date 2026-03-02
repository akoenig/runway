import Foundation
import UserNotifications

final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
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

        content.body = "\(workflow.name) in \(workflow.repository.name)"
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
                print("Failed to send notification: \(error)")
            }
        }
    }
}
