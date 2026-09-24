import SwiftUI
import MdViewerCore

/// Export/print actions published by the focused document window.
struct DocumentOutputActions {
    let exportPDF: () -> Void
    let print: () -> Void
}

extension FocusedValues {
    @Entry var documentOutputActions: DocumentOutputActions?
}

/// File menu: Export as PDF… (⇧⌘E) and Print… (⌘P).
struct FileCommands: Commands {
    @FocusedValue(\.documentOutputActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .importExport) {
            Button("Export as PDF…") { actions?.exportPDF() }
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(actions == nil)
        }
        CommandGroup(replacing: .printItem) {
            Button("Print…") { actions?.print() }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(actions == nil)
        }
    }
}
