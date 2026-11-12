import SwiftUI

/// "3 open from Fri 6 Nov — Review": the open tasks of the most recent earlier day.
struct ReviewBanner: View {
    @Bindable var model: AppModel
    @State private var expanded = false

    var body: some View {
        if let day = model.reviewDay, !model.reviewRows.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Button(action: { withAnimation(.spring(duration: 0.3)) { expanded.toggle() } }) {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("\(model.reviewRows.count) open from \(model.shortTitle(day))")
                        Spacer(minLength: 4)
                        Text(expanded ? "Hide" : "Review").fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                            .font(.system(size: 9, weight: .bold))
                    }
                    .font(.system(size: 11.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(model.reviewRows.count) open tasks from \(model.shortTitle(day)). \(expanded ? "Hide" : "Review")")

                if expanded {
                    ForEach(model.reviewRows) { row in
                        HStack(spacing: 4) {
                            Text(row.item.text)
                                .font(.system(size: 12))
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            action("arrow.down.circle", "Add to Today") { model.carry(row) }
                            action("archivebox", "Archive") { model.archive(row) }
                            action("trash", "Delete") { model.removeFromReview(row) }
                        }
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                    HStack {
                        Button("Add All") { model.carryAll() }
                        Button("Archive All") { model.archiveAll() }
                        Spacer()
                    }
                    .controlSize(.small)
                    .padding(.top, 2)
                }
            }
            .padding(9)
            .background(.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .transition(.opacity)
        }
    }

    private func action(_ symbol: String, _ label: String, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Image(systemName: symbol)
                .font(.system(size: 12))
                .frame(width: 22, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .help(label)
        .accessibilityLabel(label)
    }
}
