import Foundation

public struct ScopedSwipeGate {
    private var reducer: RailSwipeReducer
    private var gestureIsInScope: Bool?
    private var lastTimestamp: TimeInterval?

    public init(reducer: RailSwipeReducer = RailSwipeReducer()) {
        self.reducer = reducer
    }

    public mutating func handle(
        _ sample: RailSwipeSample,
        startingInScope: @autoclosure () -> Bool
    ) -> RailSwipeDecision {
        if let lastTimestamp, sample.timestamp - lastTimestamp > reducer.idleReset { reset() }
        self.lastTimestamp = sample.timestamp

        if sample.isMomentum, gestureIsInScope == nil { return .passThrough }
        if sample.phase == .began || gestureIsInScope == nil {
            gestureIsInScope = startingInScope()
            reducer.reset()
        }
        guard gestureIsInScope == true else {
            if sample.phase == .ended || sample.phase == .cancelled { reset() }
            return .passThrough
        }

        let decision = reducer.handle(sample)
        if sample.phase == .ended || sample.phase == .cancelled {
            gestureIsInScope = nil
            lastTimestamp = nil
        }
        return decision
    }

    public mutating func reset() {
        reducer.reset()
        gestureIsInScope = nil
        lastTimestamp = nil
    }
}
