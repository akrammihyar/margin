import SwiftUI
import MarginCore

struct NotesView: View {
    @Bindable var model: AppModel
    var maxEditorHeight: CGFloat
    @State private var confirmingDelete = false

    var body: some View {
        if model.showingAllNotes {
            AllNotesView(model: model, maxHeight: maxEditorHeight)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topLeading) {
                    if model.noteDraft.isEmpty {
                        Text("Write a note…")
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $model.noteDraft)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .onChange(of: model.noteDraft) { _, _ in model.noteChanged() }
                        .accessibilityLabel("Note")
                }
                .frame(height: min(220, maxEditorHeight))
                .padding(6)
                .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                if confirmingDelete {
                    HStack {
                        Text("Delete this note?").font(.system(size: 12))
                        Spacer()
                        Button("Cancel") { confirmingDelete = false }
                        Button("Delete", role: .destructive) {
                            confirmingDelete = false
                            model.deleteCurrentNote()
                        }
                    }
                    .controlSize(.small)
                } else {
                    HStack(spacing: 6) {
                        barButton("square.and.pencil", "New Note") { model.newNote() }
                            .disabled(model.noteDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        barButton("tray.full", "All Notes") {
                            model.flushNote()
                            model.showingAllNotes = true
                        }
                        Spacer()
                        barButton("trash", "Delete") { confirmingDelete = true }
                            .disabled(model.noteDraft.isEmpty)
                    }
                }
            }
        }
    }

    private func barButton(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: symbol).font(.system(size: 11.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.primary.opacity(0.06), in: Capsule())
        .help(label)
    }
}

struct AllNotesView: View {
    @Bindable var model: AppModel
    var maxHeight: CGFloat
    @State private var confirming: URL?
    @State private var listHeight: CGFloat = 0

    private static let dateFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { model.showingAllNotes = false }) {
                Label("Back", systemImage: "chevron.left").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            if model.archivedNotes.isEmpty {
                Text("No saved notes")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(model.archivedNotes) { note in
                            HStack(spacing: 6) {
                                if confirming == note.url {
                                    Text("Delete?").font(.system(size: 12)).frame(maxWidth: .infinity, alignment: .leading)
                                    Button("Cancel") { confirming = nil }
                                    Button("Delete", role: .destructive) { confirming = nil; model.delete(note) }
                                } else {
                                    Button(action: { model.open(note) }) {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(note.title).font(.system(size: 13)).lineLimit(1)
                                            Text(Self.dateFormat.string(from: note.date))
                                                .font(.system(size: 10.5))
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Open note \(note.title)")
                                    Button(action: { confirming = note.url }) {
                                        Image(systemName: "trash").font(.system(size: 11)).frame(width: 22, height: 20)
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(.secondary)
                                    .accessibilityLabel("Delete note \(note.title)")
                                }
                            }
                            .controlSize(.small)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 6)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { listHeight = $0 }
                }
                .frame(height: min(max(listHeight, 30), maxHeight))
            }
        }
    }
}
