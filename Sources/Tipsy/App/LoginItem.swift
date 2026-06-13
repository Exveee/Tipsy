import ServiceManagement

/// Wraps "start at login" using `SMAppService` (macOS 13+). The system service
/// is the source of truth for the state, so nothing is persisted separately.
///
/// Only works for the installed `.app` bundle (e.g. in /Applications); it is a
/// no-op when running via `swift run`, which has no bundle to register.
@MainActor
enum LoginItem {

    /// Whether Tipsy is registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters Tipsy as a login item. Throws on failure.
    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
