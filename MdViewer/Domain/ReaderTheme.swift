import Foundation

/// The reading themes the viewer offers. Each adapts to light and dark appearance.
public enum ReaderTheme: String, CaseIterable, Identifiable, Sendable {
    case github
    case sepia
    case academic
    case highContrast

    public static let `default` = ReaderTheme.github

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .github: "GitHub"
        case .sepia: "Sepia"
        case .academic: "Academic (Serif)"
        case .highContrast: "High Contrast"
        }
    }
}
