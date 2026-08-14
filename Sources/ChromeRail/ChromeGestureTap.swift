import AppKit
import CoreGraphics
import ChromeRailCore

private let chromeGestureCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let owner = Unmanaged<ChromeGestureTap>.fromOpaque(refcon).takeUnretainedValue()
    return owner.handle(type: type, event: event)
}

final class ChromeGestureTap {
    var isPointInVerticalTabs: ((CGPoint) -> Bool)?
    var onSelectRelative: ((Int) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var gate = ScopedSwipeGate()

    func start() -> Bool {
        guard tap == nil else { return true }
        let mask = (CGEventMask(1) << CGEventType.scrollWheel.rawValue)
            | (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: chromeGestureCallback,
            userInfo: context
        ) else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        source = nil
        tap = nil
        resetGesture()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown || type == .keyUp {
            return handleLogitechShortcut(type: type, event: event)
        }
        guard type == .scrollWheel, let nsEvent = NSEvent(cgEvent: event) else {
            return Unmanaged.passUnretained(event)
        }

        let phase = railPhase(nsEvent.phase)
        let deltas = normalizedRailScrollDeltas(
            deltaX: nsEvent.scrollingDeltaX,
            deltaY: nsEvent.scrollingDeltaY,
            isDiscrete: !nsEvent.hasPreciseScrollingDeltas
                || (nsEvent.phase.isEmpty && nsEvent.momentumPhase.isEmpty)
        )
        let decision = gate.handle(RailSwipeSample(
            deltaX: deltas.x,
            deltaY: deltas.y,
            phase: phase,
            isMomentum: !nsEvent.momentumPhase.isEmpty,
            timestamp: nsEvent.timestamp
        ), startingInScope: isPointInVerticalTabs?(event.location) == true)

        switch decision {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .consume:
            return nil
        case .selectPrevious:
            DispatchQueue.main.async { [weak self] in self?.onSelectRelative?(-1) }
            return nil
        case .selectNext:
            DispatchQueue.main.async { [weak self] in self?.onSelectRelative?(1) }
            return nil
        }
    }

    private func handleLogitechShortcut(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let hasNavigationModifier = event.flags.contains(.maskControl)
            || event.flags.contains(.maskCommand)
        guard keyCode == 48, hasNavigationModifier else {
            return Unmanaged.passUnretained(event)
        }

        let sourcePID = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
        let sourceApplication = NSRunningApplication(processIdentifier: sourcePID)
        let sourceBundleIdentifier = sourceApplication?.bundleIdentifier
        let sourceMatchedLogitech = sourceBundleIdentifier?
            .localizedCaseInsensitiveContains("logi") == true
        let pointer = CGEvent(source: nil)?.location ?? event.location
        let pointerInsideVerticalTabs = isPointInVerticalTabs?(pointer) == true
        let direction = logitechTabDirection(
            keyCode: keyCode,
            hasNavigationModifier: hasNavigationModifier,
            hasShift: event.flags.contains(.maskShift),
            sourceIsLogitech: sourceMatchedLogitech
        )
        let intercepted = direction != nil && pointerInsideVerticalTabs
        DispatchQueue.main.async {
            DiagnosticsStore.writeShortcutIfChanged(LogitechShortcutProbe(
                generatedAt: Date(),
                eventType: type.rawValue,
                keyCode: keyCode,
                sourceProcessIdentifier: sourcePID,
                sourceBundleIdentifier: sourceBundleIdentifier,
                sourceMatchedLogitech: sourceMatchedLogitech,
                pointerInsideVerticalTabs: pointerInsideVerticalTabs,
                intercepted: intercepted
            ))
        }
        guard let direction, pointerInsideVerticalTabs else {
            return Unmanaged.passUnretained(event)
        }
        if type == .keyDown, event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            DispatchQueue.main.async { [weak self] in self?.onSelectRelative?(direction) }
        }
        return nil
    }

    private func resetGesture() {
        gate.reset()
    }

    private func railPhase(_ phase: NSEvent.Phase) -> RailScrollPhase {
        if phase.contains(.began) { return .began }
        if phase.contains(.changed) { return .changed }
        if phase.contains(.ended) { return .ended }
        if phase.contains(.cancelled) { return .cancelled }
        return .none
    }
}
