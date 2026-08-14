import AppKit
import ApplicationServices

struct WindowProbe: Codable {
    let index: Int
    let isFocused: Bool
    let isMinimized: Bool
    let hasVerticalTabs: Bool
}

struct ChromeProbeReport: Codable {
    let generatedAt: Date
    let chromeVersion: String
    let gestureTapAvailable: Bool
    let windows: [WindowProbe]
}

final class ResolvedChromeWindow {
    let element: AXUIElement
    let isFocused: Bool
    let isMinimized: Bool
    let verticalTabsElement: AXUIElement?

    init(
        element: AXUIElement,
        isFocused: Bool,
        isMinimized: Bool,
        verticalTabsElement: AXUIElement?
    ) {
        self.element = element
        self.isFocused = isFocused
        self.isMinimized = isMinimized
        self.verticalTabsElement = verticalTabsElement
    }
}

struct ChromeResolution {
    let application: NSRunningApplication
    let applicationElement: AXUIElement
    let windows: [ResolvedChromeWindow]
}

final class ChromeWindowResolver {
    static let chromeBundleID = "com.google.Chrome"

    func resolve() -> ChromeResolution? {
        guard let chrome = NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.chromeBundleID
        ).first else { return nil }
        let applicationElement = AXUIElementCreateApplication(chrome.processIdentifier)
        guard let elements: [AXUIElement] = AXSupport.copy(
            applicationElement,
            kAXWindowsAttribute as CFString
        ) else {
            return ChromeResolution(application: chrome, applicationElement: applicationElement, windows: [])
        }

        let focused: AXUIElement? = AXSupport.copy(
            applicationElement,
            kAXFocusedWindowAttribute as CFString
        )
        let windows = elements.compactMap { element -> ResolvedChromeWindow? in
            let role = AXSupport.string(element, kAXRoleAttribute as CFString)
            let subrole = AXSupport.string(element, kAXSubroleAttribute as CFString)
            guard role == (kAXWindowRole as String),
                  subrole == nil || subrole == (kAXStandardWindowSubrole as String),
                  let windowFrame = AXSupport.frame(of: element) else { return nil }
            return ResolvedChromeWindow(
                element: element,
                isFocused: AXSupport.same(element, focused),
                isMinimized: AXSupport.bool(element, kAXMinimizedAttribute as CFString) ?? false,
                verticalTabsElement: verticalTabsElement(in: element, windowFrame: windowFrame)
            )
        }
        return ChromeResolution(
            application: chrome,
            applicationElement: applicationElement,
            windows: windows
        )
    }

    func report(resolution: ChromeResolution?, gestureTapAvailable: Bool) -> ChromeProbeReport {
        let version = Bundle(path: "/Applications/Google Chrome.app")?
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let probes = resolution?.windows.enumerated().map { index, window in
            WindowProbe(
                index: index,
                isFocused: window.isFocused,
                isMinimized: window.isMinimized,
                hasVerticalTabs: window.verticalTabsElement != nil
            )
        } ?? []
        return ChromeProbeReport(
            generatedAt: Date(),
            chromeVersion: version,
            gestureTapAvailable: gestureTapAvailable,
            windows: probes
        )
    }

    private func verticalTabsElement(in window: AXUIElement, windowFrame: CGRect) -> AXUIElement? {
        var stack = [window]
        var visited = 0
        while let element = stack.popLast(), visited < 1800 {
            visited += 1
            let role = AXSupport.string(element, kAXRoleAttribute as CFString) ?? ""
            if role == AXSupport.webAreaRole { continue }
            if role == "AXTabGroup", let frame = AXSupport.frame(of: element),
               frame.height >= windowFrame.height * 0.7,
               frame.width <= windowFrame.width * 0.4,
               abs(frame.minX - windowFrame.minX) <= 4 {
                return element
            }
            guard let children: [AXUIElement] = AXSupport.copy(
                element,
                kAXChildrenAttribute as CFString
            ) else { continue }
            stack.append(contentsOf: children.reversed())
        }
        return nil
    }
}
