import Foundation

/// Page zoom rules: fixed steps within a clamped range.
public enum PageZoom {
    public static let actualSize = 1.0
    public static let minimum = 0.5
    public static let maximum = 3.0
    public static let step = 0.1

    public static func zoomedIn(from zoom: Double) -> Double {
        clamped(zoom + step)
    }

    public static func zoomedOut(from zoom: Double) -> Double {
        clamped(zoom - step)
    }

    /// Clamps to the allowed range and rounds to one decimal (the step grid) to avoid float drift.
    public static func clamped(_ zoom: Double) -> Double {
        let rounded = (zoom * 10).rounded() / 10
        return min(max(rounded, minimum), maximum)
    }

    public static func canZoomIn(from zoom: Double) -> Bool { zoom < maximum - step / 2 }
    public static func canZoomOut(from zoom: Double) -> Bool { zoom > minimum + step / 2 }
}
