import SwiftUI

/// Presentational view: the document outline, indented by heading level.
struct OutlineSidebarView: View {
    let entries: [OutlineEntry]
    let activeSlug: String?
    let onSelect: (OutlineEntry) -> Void

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView("No Headings", systemImage: "list.bullet.indent")
        } else {
            List(entries) { entry in
                Button {
                    onSelect(entry)
                } label: {
                    Text(entry.heading.text)
                        .lineLimit(2)
                        .fontWeight(entry.indent == 0 ? .semibold : .regular)
                        .foregroundStyle(entry.id == activeSlug ? Color.accentColor : Color.primary)
                        .padding(.leading, CGFloat(entry.indent) * 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    entry.id == activeSlug
                        ? RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.15))
                        : nil
                )
            }
            .listStyle(.sidebar)
        }
    }
}

#Preview {
    OutlineSidebarView(
        entries: TableOfContents.entries(from: [
            Heading(level: 1, text: "Title", slug: "title"),
            Heading(level: 2, text: "Section", slug: "section"),
            Heading(level: 3, text: "Subsection", slug: "subsection"),
        ]),
        activeSlug: "section",
        onSelect: { _ in }
    )
    .frame(width: 220, height: 300)
}
