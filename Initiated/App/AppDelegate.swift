import AppKit
import Carbon
import Combine
import SwiftUI
import UserNotifications

/// File-scope C-compatible callback for Carbon hotkey events.
/// Posts a notification so the @MainActor AppDelegate can handle it
/// without crossing actor boundaries from the C callback.
private func hotkeyCallback(
    _: EventHandlerCallRef?,
    _: EventRef?,
    _: UnsafeMutableRawPointer?
) -> OSStatus {
    NotificationCenter.default.post(name: .hotkeyToggle, object: nil)
    return noErr
}

private extension Notification.Name {
    static let hotkeyToggle = Notification.Name("com.initiated.hotkeyToggle")
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?
    private var hotkeyRef: EventHotKeyRef?
    private var hotkeyHandler: EventHandlerRef?
    private var cancellables = Set<AnyCancellable>()

    private let viewModel = AppViewModel()
    private let notificationService = NotificationService()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide the main window immediately
        NSApp.windows.first?.close()

        setupMenuBar()
        setupStatusIconObserver()
        setupNotifications()
        setupEventMonitor()
        setupHotkey()

        Task {
            await viewModel.startMonitoring()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel.stopMonitoring()
        removeEventMonitor()
        unregisterHotkey()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = makeStatusDot(color: .systemGray)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 340, height: 420)
        popover?.behavior = .transient
        popover?.animates = false
        popover?.contentViewController = NSHostingController(rootView: MenuBarView(viewModel: viewModel))
    }

    /// Observe workflow changes via Combine to reactively update the menu bar dot.
    /// This replaces the manual updateStatusIcon() calls in the view model and
    /// ensures the dot always reflects the current state.
    private func setupStatusIconObserver() {
        viewModel.$workflows
            .combineLatest(viewModel.$isAuthenticated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                guard let self = self else { return }
                self.updateStatusIcon(status: self.viewModel.overallStatus)
            }
            .store(in: &cancellables)
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

    // MARK: - Global Hotkey

    private func setupHotkey() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(togglePopover),
            name: .hotkeyToggle,
            object: nil
        )

        viewModel.onShortcutChanged = { [weak self] in
            self?.registerHotkey()
        }

        registerHotkey()
    }

    private func registerHotkey() {
        unregisterHotkey()

        let keyCode = viewModel.shortcutKeyCode
        let modifiers = viewModel.shortcutModifiers
        guard keyCode >= 0 else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCallback,
            1,
            &eventType,
            nil,
            &hotkeyHandler
        )

        var hotKeyID = EventHotKeyID(signature: 0x494E4954, id: 1)

        RegisterEventHotKey(
            UInt32(keyCode),
            carbonFlags(from: modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = hotkeyHandler {
            RemoveEventHandler(handler)
            hotkeyHandler = nil
        }
    }

    private func carbonFlags(from cocoaModifiers: Int) -> UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(cocoaModifiers))
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    // MARK: - Popover

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Status Icon

    private func updateStatusIcon(status: WorkflowStatus) {
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
