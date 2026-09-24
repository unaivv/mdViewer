import SwiftUI
import MdViewerCore

/// View menu: reader theme picker and page zoom. Both persist and apply to every window.
struct ViewCommands: Commands {
    @AppStorage(AppSettings.readerThemeKey) private var theme = ReaderTheme.default
    @AppStorage(AppSettings.pageZoomKey) private var zoom = PageZoom.actualSize

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Picker("Theme", selection: $theme) {
                ForEach(ReaderTheme.allCases) { theme in
                    Text(theme.displayName).tag(theme)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Button("Actual Size") { zoom = PageZoom.actualSize }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(zoom == PageZoom.actualSize)
            Button("Zoom In") { zoom = PageZoom.zoomedIn(from: zoom) }
                .keyboardShortcut("+", modifiers: .command)
                .disabled(!PageZoom.canZoomIn(from: zoom))
            Button("Zoom Out") { zoom = PageZoom.zoomedOut(from: zoom) }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!PageZoom.canZoomOut(from: zoom))

            Divider()
        }
    }
}
