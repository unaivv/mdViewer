import SwiftUI

/// Find actions published by the focused document window.
struct FindActions {
    let showFindBar: () -> Void
    let findNext: () -> Void
    let findPrevious: () -> Void
}

extension FocusedValues {
    @Entry var findActions: FindActions?
}

/// Edit > Find menu (⌘F, ⌘G, ⇧⌘G) routed to the focused document window.
struct FindCommands: Commands {
    @FocusedValue(\.findActions) private var findActions

    var body: some Commands {
        CommandGroup(replacing: .textEditing) {
            Menu("Find") {
                Button("Find…") { findActions?.showFindBar() }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") { findActions?.findNext() }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") { findActions?.findPrevious() }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
            }
            .disabled(findActions == nil)
        }
    }
}
