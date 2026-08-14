import Foundation

public func normalizedRailScrollDeltas(
    deltaX: Double,
    deltaY: Double,
    isDiscrete: Bool,
    threshold: Double = 56
) -> (x: Double, y: Double) {
    let largest = max(abs(deltaX), abs(deltaY))
    guard isDiscrete, largest > 0, largest < threshold else { return (deltaX, deltaY) }
    let scale = threshold / largest
    return (deltaX * scale, deltaY * scale)
}

public func logitechTabDirection(
    keyCode: Int64,
    hasNavigationModifier: Bool,
    hasShift: Bool,
    sourceIsLogitech: Bool
) -> Int? {
    guard keyCode == 48, hasNavigationModifier, sourceIsLogitech else { return nil }
    return hasShift ? -1 : 1
}

public enum RailSwipeDecision: Equatable, Sendable {
    case passThrough
    case consume
    case selectPrevious
    case selectNext
}

public enum RailScrollPhase: Equatable, Sendable {
    case none
    case began
    case changed
    case ended
    case cancelled
}

public struct RailSwipeSample: Equatable, Sendable {
    public let deltaX: Double
    public let deltaY: Double
    public let phase: RailScrollPhase
    public let isMomentum: Bool
    public let timestamp: TimeInterval

    public init(
        deltaX: Double,
        deltaY: Double,
        phase: RailScrollPhase,
        isMomentum: Bool,
        timestamp: TimeInterval
    ) {
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.phase = phase
        self.isMomentum = isMomentum
        self.timestamp = timestamp
    }
}

public struct RailSwipeReducer: Sendable {
    public var threshold: Double
    public var horizontalDominance: Double
    public var idleReset: TimeInterval

    private var accumulatedX = 0.0
    private var active = false
    private var rejected = false
    private var switched = false
    private var lastTimestamp: TimeInterval?

    public init(threshold: Double = 56, horizontalDominance: Double = 1.35, idleReset: TimeInterval = 0.28) {
        self.threshold = threshold
        self.horizontalDominance = horizontalDominance
        self.idleReset = idleReset
    }

    public mutating func handle(_ sample: RailSwipeSample) -> RailSwipeDecision {
        if let lastTimestamp, sample.timestamp - lastTimestamp > idleReset {
            reset()
        }
        lastTimestamp = sample.timestamp

        if sample.phase == .began { reset(keepingTimestamp: true) }

        if sample.isMomentum {
            return active ? .consume : .passThrough
        }

        if sample.phase == .ended || sample.phase == .cancelled {
            let decision: RailSwipeDecision = active ? .consume : .passThrough
            reset()
            return decision
        }

        if rejected { return .passThrough }
        if switched { return .consume }

        let horizontal = abs(sample.deltaX)
        let vertical = abs(sample.deltaY)
        guard horizontal > 0 || vertical > 0 else {
            return active ? .consume : .passThrough
        }
        guard horizontal > 0, horizontal >= vertical * horizontalDominance else {
            if !active { rejected = true }
            return active ? .consume : .passThrough
        }

        active = true
        accumulatedX += sample.deltaX
        guard abs(accumulatedX) >= threshold else { return .consume }

        switched = true
        return accumulatedX < 0 ? .selectNext : .selectPrevious
    }

    public mutating func reset() {
        reset(keepingTimestamp: false)
    }

    private mutating func reset(keepingTimestamp: Bool) {
        accumulatedX = 0
        active = false
        rejected = false
        switched = false
        if !keepingTimestamp { lastTimestamp = nil }
    }
}
