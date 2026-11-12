import SwiftUI

/// `‹  Today · Thu 12 Nov  ›`
struct DayNavigator: View {
    @Bindable var model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            arrow("chevron.left", label: "Previous day", action: model.goPrevious)
            Button(action: model.goToToday) {
                Text(model.dayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Go to today")
            .accessibilityLabel("\(model.dayTitle). Go to today")
            arrow("chevron.right", label: "Next day", action: model.goNext)
                .disabled(!model.canGoNext)
                .opacity(model.canGoNext ? 1 : 0.3)
        }
    }

    private func arrow(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
