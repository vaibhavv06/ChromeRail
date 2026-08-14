import AppKit
import ApplicationServices

final class OnboardingWindowController: NSWindowController {
    var onPermissionGranted: (() -> Void)?
    private let statusLabel = NSTextField(labelWithString: "")
    private var timer: Timer?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 250),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Set up ChromeRail"
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) { nil }

    func begin() {
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
        requestPermission()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.refreshPermission()
        }
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let title = NSTextField(labelWithString: "Allow Accessibility")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false

        let body = NSTextField(wrappingLabelWithString:
            "ChromeRail needs one macOS permission to cycle Chrome windows and limit horizontal switching to Chrome's vertical-tabs area. It never reads webpages, tab titles, profile data, passwords, cookies, or Google credentials."
        )
        body.font = .systemFont(ofSize: 13)
        body.textColor = .secondaryLabelColor
        body.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.stringValue = "Waiting for permission…"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        let settingsButton = NSButton(title: "Open System Settings", target: self, action: #selector(openSettings))
        settingsButton.bezelStyle = .rounded
        settingsButton.translatesAutoresizingMaskIntoConstraints = false

        let quitButton = NSButton(title: "Quit", target: self, action: #selector(quit))
        quitButton.bezelStyle = .rounded
        quitButton.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(title)
        content.addSubview(body)
        content.addSubview(statusLabel)
        content.addSubview(settingsButton)
        content.addSubview(quitButton)

        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            title.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            title.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            body.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            body.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 14),
            statusLabel.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            statusLabel.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 18),
            settingsButton.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            settingsButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            quitButton.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            quitButton.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
        ])
    }

    private func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func refreshPermission() {
        guard AXIsProcessTrusted() else { return }
        timer?.invalidate()
        timer = nil
        statusLabel.stringValue = "Permission granted. Starting ChromeRail…"
        window?.orderOut(nil)
        onPermissionGranted?()
    }

    @objc private func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
