import AppKit
import ApplicationServices

private let chromeAXCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else { return }
    let owner = Unmanaged<ChromeEventObserver>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async { owner.scheduleChange() }
}

final class ChromeEventObserver {
    var onChange: (() -> Void)?
    private var observer: AXObserver?
    private var processIdentifier: pid_t?
    private var applicationElement: AXUIElement?
    private var observedElements: [AXUIElement] = []
    private var pendingChange: DispatchWorkItem?

    func bind(to resolution: ChromeResolution?) {
        guard let resolution else {
            teardown()
            return
        }
        let liveElements = resolution.windows.flatMap { window in
            [window.element] + [window.verticalTabsElement].compactMap { $0 }
        }
        if observedElements.contains(where: { observed in
            !liveElements.contains(where: { AXSupport.same($0, observed) })
        }) {
            teardown()
        }
        if observer == nil || processIdentifier != resolution.application.processIdentifier {
            teardown()
            var created: AXObserver?
            guard AXObserverCreate(resolution.application.processIdentifier, chromeAXCallback, &created) == .success,
                  let created else { return }
            observer = created
            processIdentifier = resolution.application.processIdentifier
            applicationElement = resolution.applicationElement
            CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
            register(
                resolution.applicationElement,
                notifications: [
                    kAXWindowCreatedNotification,
                    kAXFocusedWindowChangedNotification,
                    kAXMainWindowChangedNotification,
                ]
            )
        }

        for window in resolution.windows where !observedElements.contains(where: { CFEqual($0, window.element) }) {
            observedElements.append(window.element)
            register(
                window.element,
                notifications: [
                    kAXMovedNotification,
                    kAXResizedNotification,
                    kAXUIElementDestroyedNotification,
                    kAXWindowMiniaturizedNotification,
                    kAXWindowDeminiaturizedNotification,
                    kAXTitleChangedNotification,
                ]
            )
        }
        for tabsElement in resolution.windows.compactMap(\.verticalTabsElement)
        where !observedElements.contains(where: { CFEqual($0, tabsElement) }) {
            observedElements.append(tabsElement)
            register(
                tabsElement,
                notifications: [
                    kAXMovedNotification,
                    kAXResizedNotification,
                    "AXLayoutChanged",
                ]
            )
        }
    }

    func scheduleChange() {
        pendingChange?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.onChange?() }
        pendingChange = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
    }

    func teardown() {
        pendingChange?.cancel()
        pendingChange = nil
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        processIdentifier = nil
        applicationElement = nil
        observedElements.removeAll()
    }

    private func register(_ element: AXUIElement, notifications: [String]) {
        guard let observer else { return }
        let context = Unmanaged.passUnretained(self).toOpaque()
        for notification in notifications {
            let result = AXObserverAddNotification(observer, element, notification as CFString, context)
            if result != .success && result != .notificationAlreadyRegistered {
                NSLog("ChromeRail could not observe \(notification): \(result.rawValue)")
            }
        }
    }
}
