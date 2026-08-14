import AppKit
import ApplicationServices

final class AppCoordinator {
    private let resolver = ChromeWindowResolver()
    private let chromeObserver = ChromeEventObserver()
    private let gestureTap = ChromeGestureTap()
    private var resolution: ChromeResolution?
    private var stableWindowOrder: [AXUIElement] = []
    private var gestureTapAvailable = false
    private var refreshWork: DispatchWorkItem?
    private var workspaceTokens: [NSObjectProtocol] = []

    func start() {
        chromeObserver.onChange = { [weak self] in self?.scheduleRefresh() }
        gestureTap.isPointInVerticalTabs = { [weak self] point in
            self?.isPointInActiveVerticalTabs(point) == true
        }
        gestureTap.onSelectRelative = { [weak self] offset in self?.selectRelative(offset) }
        gestureTapAvailable = gestureTap.start()
        if !gestureTapAvailable {
            NSLog("ChromeRail could not create its scoped scroll event tap")
        }

        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ] {
            workspaceTokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleRefresh()
            })
        }
        refresh()
    }

    func stop() {
        workspaceTokens.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceTokens.removeAll()
        chromeObserver.teardown()
        gestureTap.stop()
    }

    func refreshNow() {
        scheduleRefresh(after: 0)
    }

    private func scheduleRefresh(after delay: TimeInterval = 0.08) {
        refreshWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refresh() }
        refreshWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func refresh() {
        resolution = resolver.resolve()
        if let resolution { updateStableWindowOrder(with: resolution.windows) }
        else { stableWindowOrder.removeAll() }
        chromeObserver.bind(to: resolution)
        DiagnosticsStore.writeIfChanged(resolver.report(
            resolution: resolution,
            gestureTapAvailable: gestureTapAvailable
        ))
    }

    private func isPointInActiveVerticalTabs(_ point: CGPoint) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == ChromeWindowResolver.chromeBundleID,
              let active = resolution?.windows.first(where: \.isFocused),
              let tabsElement = active.verticalTabsElement,
              let frame = AXSupport.frame(of: tabsElement) else { return false }
        return frame.contains(point)
    }

    private func selectRelative(_ offset: Int) {
        guard let resolution,
              stableWindowOrder.count >= 2,
              let active = resolution.windows.first(where: \.isFocused),
              let current = stableWindowOrder.firstIndex(where: { AXSupport.same($0, active.element) }) else { return }
        let destination = (current + offset + stableWindowOrder.count) % stableWindowOrder.count
        guard destination != current,
              let target = resolution.windows.first(where: {
                AXSupport.same($0.element, stableWindowOrder[destination])
              }) else { return }
        focus(target, resolution: resolution)
    }

    private func focus(_ target: ResolvedChromeWindow, resolution: ChromeResolution) {
        if target.isMinimized {
            _ = AXSupport.setBool(target.element, kAXMinimizedAttribute as CFString, value: false)
        }
        _ = AXSupport.perform(target.element, kAXRaiseAction as CFString)
        _ = AXSupport.set(
            resolution.applicationElement,
            kAXFocusedWindowAttribute as CFString,
            value: target.element
        )
        _ = resolution.application.activate(options: [.activateIgnoringOtherApps])
        scheduleRefresh(after: 0.12)
    }

    private func updateStableWindowOrder(with windows: [ResolvedChromeWindow]) {
        stableWindowOrder.removeAll { known in
            !windows.contains(where: { AXSupport.same($0.element, known) })
        }
        for window in windows where !stableWindowOrder.contains(where: { AXSupport.same($0, window.element) }) {
            stableWindowOrder.append(window.element)
        }
    }
}
