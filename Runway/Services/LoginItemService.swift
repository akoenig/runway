import ServiceManagement

/// Wraps SMAppService to register/unregister the app as a login item.
/// Requires macOS 13+; we target 14 so this is always available.
final class LoginItemService {
    static let shared = LoginItemService()
    private init() {}

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func enable() throws {
        try SMAppService.mainApp.register()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
    }

    func toggle() throws {
        if isEnabled {
            try disable()
        } else {
            try enable()
        }
    }
}
