import AppKit
import Observation

@Observable
@MainActor
final class ShortcutRecorder {
    var isRecording: Bool = false

    /// Stored as `nonisolated(unsafe)` so `deinit` can clean up the monitor
    /// without crossing actor boundaries. Safety is ensured because all
    /// mutations happen on the main actor (the class is `@MainActor`), and
    /// at deinit time no other references exist.
    nonisolated(unsafe) private var monitor: Any?
    private var completion: ((UInt16, NSEvent.ModifierFlags, String) -> Void)?

    func startRecording(completion: @escaping (UInt16, NSEvent.ModifierFlags, String) -> Void) {
        self.completion = completion
        isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self = self else { return }

                // Escape cancels recording
                if event.keyCode == 53 {
                    self.stopRecording()
                    return
                }

                // Require at least one modifier (Cmd, Opt, Ctrl, Shift)
                let required: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
                guard !event.modifierFlags.intersection(required).isEmpty else {
                    return
                }

                let displayChar = Self.displayString(for: event.keyCode, characters: event.charactersIgnoringModifiers)
                self.completion?(event.keyCode, event.modifierFlags.intersection(required), displayChar)
                self.stopRecording()
            }
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

    nonisolated deinit {
        // NSEvent monitor cleanup is safe to call from any context.
        // At deinit time, no other references exist, so there is no race.
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
