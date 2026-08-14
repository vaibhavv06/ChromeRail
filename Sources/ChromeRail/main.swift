import AppKit
import ApplicationServices

final class ChromeRailAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: AppCoordinator?
    private var onboarding: OnboardingWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard enforceSingleInstance() else { return }
        if AXIsProcessTrusted() {
            startCoordinator()
        } else {
            let onboarding = OnboardingWindowController()
            onboarding.onPermissionGranted = { [weak self] in self?.startCoordinator() }
            self.onboarding = onboarding
            onboarding.begin()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if AXIsProcessTrusted() {
            coordinator?.refreshNow()
        } else {
            onboarding?.begin()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    private func startCoordinator() {
        onboarding?.close()
        onboarding = nil
        let coordinator = AppCoordinator()
        self.coordinator = coordinator
        coordinator.start()
    }

    private func enforceSingleInstance() -> Bool {
        guard let bundleID = Bundle.main.bundleIdentifier else { return true }
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard let existing = others.first else { return true }
        _ = existing.activate(options: [.activateIgnoringOtherApps])
        NSApp.terminate(nil)
        return false
    }
}

let app = NSApplication.shared
let delegate = ChromeRailAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
