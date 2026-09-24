import SwiftUI
import MdViewerCore

/// Result of the last find operation, as shown in the find bar.
enum FindStatus: Equatable {
    case idle
    case found
    case notFound
}

/// Presentational view: an inline find bar (query field, previous/next, done).
struct FindBarView: View {
    @Binding var query: String
    let status: FindStatus
    /// Changes whenever the field should (re)gain keyboard focus.
    let focusToken: Int
    let onNext: () -> Void
    let onPrevious: () -> Void
    let onClose: () -> Void

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("Find", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
                .focused($isFieldFocused)
                .onSubmit(onNext)

            if status == .notFound {
                Text("Not found")
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            ControlGroup {
                Button(action: onPrevious) { Image(systemName: "chevron.left") }
                    .help("Find Previous (⇧⌘G)")
                Button(action: onNext) { Image(systemName: "chevron.right") }
                    .help("Find Next (⌘G)")
            }
            .fixedSize()
            .disabled(query.isEmpty)

            Spacer()

            Button("Done", action: onClose)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
        .onExitCommand(perform: onClose)
        .onAppear { isFieldFocused = true }
        .onChange(of: focusToken) { isFieldFocused = true }
    }
}

#Preview {
    FindBarView(
        query: .constant("swift"), status: .notFound, focusToken: 0,
        onNext: {}, onPrevious: {}, onClose: {}
    )
    .frame(width: 600)
}
