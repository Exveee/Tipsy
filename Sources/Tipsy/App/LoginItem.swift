import ServiceManagement

/// Wraps "start at login" using `SMAppService` (macOS 13+). The system service
/// is the source of truth for the state, so nothing is persisted separately.
///
/// Only works for the installed `.app` bundle (e.g. in /Applications); it is a
/// no-op when running via `swift run`, which has no bundle to register.
///
/// Security note: both the login item registered here and the system
/// Accessibility (TCC) grant bind to the bundle's *designated requirement*. A
/// self-signed or ad-hoc identity yields a weak requirement, so anyone able to
/// write `/Applications/Tipsy.app` could swap in a replacement bundle and
/// inherit auto-start plus the Accessibility grant (post-compromise
/// persistence; see GitHub issue #23). This cannot be enforced from code. For
/// builds distributed to other machines, sign and notarize with a Developer ID
/// so these privileges bind to a strong Team-ID-backed requirement; the
/// self-signed/ad-hoc path is for local/dev use only.
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
