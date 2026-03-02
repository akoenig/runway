import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    private let viewModel = AppViewModel()
    private let notificationService = NotificationService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the main window immediately
        NSApp.windows.first?.close()

        setupMenuBar()
        setupNotifications()
        setupEventMonitor()

        Task {
            await viewModel.startMonitoring()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopMonitoring()
        removeEventMonitor()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = makeStatusDot(color: .systemGray)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 360)
        popover?.behavior = .transient
        popover?.animates = true
        popover?.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: viewModel))
    }

    private func setupNotifications() {
        notificationService.requestAuthorization()

        viewModel.onWorkflowCompleted = { [weak self] workflow in
            self?.notificationService.sendNotification(for: workflow)
        }
    }

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func updateStatusIcon(status: WorkflowStatus) {
        guard let button = statusItem?.button else { return }

        let color: NSColor = switch status {
        case .idle:
            .systemGray
        case .running:
            .systemOrange
        case .success:
            .systemGreen
        case .failure:
            .systemRed
        }

        button.image = makeStatusDot(color: color)
    }

    /// Draws a small colored circle suitable for the menu bar.
    /// The dot is 8pt within an 18x18 canvas so it sits nicely
    /// alongside other menu bar items.
    private func makeStatusDot(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { bounds in
            let dotSize: CGFloat = 8
            let origin = CGPoint(
                x: (bounds.width - dotSize) / 2,
                y: (bounds.height - dotSize) / 2
            )
            let dotRect = NSRect(origin: origin, size: NSSize(width: dotSize, height: dotSize))
            color.setFill()
            NSBezierPath(ovalIn: dotRect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
