import ApplicationServices
import CoreGraphics

enum AXSupport {
    static let fullScreenAttribute = "AXFullScreen" as CFString
    static let webAreaRole = "AXWebArea"

    static func copy<T>(_ element: AXUIElement, _ attribute: CFString, as type: T.Type = T.self) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &value) == .success else { return nil }
        return value as? T
    }

    static func string(_ element: AXUIElement, _ attribute: CFString) -> String? {
        copy(element, attribute, as: String.self)
    }

    static func bool(_ element: AXUIElement, _ attribute: CFString) -> Bool? {
        copy(element, attribute, as: Bool.self)
    }

    static func set(_ element: AXUIElement, _ attribute: CFString, value: CFTypeRef) -> Bool {
        AXUIElementSetAttributeValue(element, attribute, value) == .success
    }

    static func setBool(_ element: AXUIElement, _ attribute: CFString, value: Bool) -> Bool {
        set(element, attribute, value: value ? kCFBooleanTrue : kCFBooleanFalse)
    }

    static func perform(_ element: AXUIElement, _ action: CFString) -> Bool {
        AXUIElementPerformAction(element, action) == .success
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard let position: AXValue = copy(element, kAXPositionAttribute as CFString),
              let size: AXValue = copy(element, kAXSizeAttribute as CFString) else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point),
              AXValueGetValue(size, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }

    static func setFrame(_ frame: CGRect, on element: AXUIElement) -> Bool {
        var point = frame.origin
        var size = frame.size
        guard let pointValue = AXValueCreate(.cgPoint, &point),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return false }
        let positionSet = set(element, kAXPositionAttribute as CFString, value: pointValue)
        let sizeSet = set(element, kAXSizeAttribute as CFString, value: sizeValue)
        return positionSet && sizeSet
    }

    static func same(_ lhs: AXUIElement, _ rhs: AXUIElement?) -> Bool {
        guard let rhs else { return false }
        return CFEqual(lhs, rhs)
    }

    static func nearlyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 0.5) -> Bool {
        abs(lhs.minX - rhs.minX) <= tolerance
            && abs(lhs.minY - rhs.minY) <= tolerance
            && abs(lhs.width - rhs.width) <= tolerance
            && abs(lhs.height - rhs.height) <= tolerance
    }
}
