import Foundation
import ChromeRailCore

enum CheckFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message): return message
        }
    }
}

@main
enum ChromeRailChecks {
    static func main() throws {
        try swipeChecks()
        try scopedGestureChecks()
        try discreteMouseChecks()
        try logitechShortcutChecks()
        print("ChromeRail checks passed (gesture scope and direction safety cases)")
    }

    private static func swipeChecks() throws {
        var reducer = RailSwipeReducer(threshold: 50)
        try expect(reducer.handle(sample(-12, 0, .began, at: 0)) == .consume, "Horizontal gesture was not captured")
        try expect(reducer.handle(sample(-40, 2, .changed, at: 0.02)) == .selectNext, "Left swipe did not select next")
        try expect(reducer.handle(sample(-80, 0, .changed, at: 0.04)) == .consume, "A gesture switched more than once")
        try expect(reducer.handle(sample(-30, 0, .changed, momentum: true, at: 0.06)) == .consume, "Momentum escaped an active gesture")

        reducer.reset()
        try expect(reducer.handle(sample(2, -30, .began, at: 0)) == .passThrough, "Vertical scroll was captured")
        try expect(reducer.handle(sample(-60, 1, .changed, at: 0.02)) == .passThrough, "A vertical gesture was reclassified as horizontal")
        try expect(reducer.handle(sample(0, 0, .ended, at: 0.04)) == .passThrough, "A rejected gesture was consumed at its end")

        var idleReducer = RailSwipeReducer(threshold: 30, idleReset: 0.2)
        _ = idleReducer.handle(sample(-35, 0, .began, at: 0))
        try expect(idleReducer.handle(sample(35, 0, .none, at: 0.5)) == .selectPrevious, "Idle gap did not begin a new gesture")
    }

    private static func scopedGestureChecks() throws {
        var outsideGate = ScopedSwipeGate(reducer: RailSwipeReducer(threshold: 30))
        try expect(
            outsideGate.handle(sample(-20, 0, .began, at: 0), startingInScope: false) == .passThrough,
            "A gesture beginning outside the sidebar was captured"
        )
        try expect(
            outsideGate.handle(sample(-40, 0, .changed, at: 0.02), startingInScope: true) == .passThrough,
            "A gesture was captured after entering the sidebar mid-gesture"
        )

        var insideGate = ScopedSwipeGate(reducer: RailSwipeReducer(threshold: 30))
        try expect(
            insideGate.handle(sample(-10, 0, .began, at: 0), startingInScope: true) == .consume,
            "A horizontal sidebar gesture leaked to Chrome"
        )
        try expect(
            insideGate.handle(sample(-25, 0, .changed, at: 0.02), startingInScope: false) == .selectNext,
            "A sidebar gesture did not remain captured after leaving its start region"
        )
    }

    private static func discreteMouseChecks() throws {
        let horizontal = normalizedRailScrollDeltas(deltaX: -1, deltaY: 0, isDiscrete: true)
        var horizontalGate = ScopedSwipeGate()
        try expect(
            horizontalGate.handle(
                sample(horizontal.x, horizontal.y, .none, at: 0),
                startingInScope: true
            ) == .selectNext,
            "A discrete horizontal mouse-wheel step did not switch"
        )

        let vertical = normalizedRailScrollDeltas(deltaX: 0, deltaY: -1, isDiscrete: true)
        var verticalGate = ScopedSwipeGate()
        try expect(
            verticalGate.handle(
                sample(vertical.x, vertical.y, .none, at: 0),
                startingInScope: true
            ) == .passThrough,
            "A discrete vertical mouse-wheel step was captured"
        )
    }

    private static func logitechShortcutChecks() throws {
        try expect(
            logitechTabDirection(
                keyCode: 48,
                hasNavigationModifier: true,
                hasShift: false,
                sourceIsLogitech: true
            ) == 1,
            "Logitech next-tab shortcut was not recognized"
        )
        try expect(
            logitechTabDirection(
                keyCode: 48,
                hasNavigationModifier: true,
                hasShift: true,
                sourceIsLogitech: true
            ) == -1,
            "Logitech previous-tab shortcut was not recognized"
        )
        try expect(
            logitechTabDirection(
                keyCode: 48,
                hasNavigationModifier: true,
                hasShift: false,
                sourceIsLogitech: false
            ) == nil,
            "A physical keyboard tab shortcut was captured"
        )
    }

    private static func sample(
        _ x: Double,
        _ y: Double,
        _ phase: RailScrollPhase,
        momentum: Bool = false,
        at time: TimeInterval
    ) -> RailSwipeSample {
        RailSwipeSample(deltaX: x, deltaY: y, phase: phase, isMomentum: momentum, timestamp: time)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw CheckFailure.failed(message) }
    }
}
