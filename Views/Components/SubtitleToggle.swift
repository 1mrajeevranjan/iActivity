import SwiftUI

/// The canonical macOS settings row: title hard-left, helper text beneath it, switch hard-right at
/// System Settings scale. Used everywhere a boolean setting appears so text and control alignment
/// are identical across every pane.
struct SubtitleToggle: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                // NSSwitch mid-animation state changes strand the knob visually wrong (renders
                // "off" while isOn is true) — kill the implicit animation so a rapid re-toggle
                // redraws outright instead of interrupting an in-flight transition.
                .animation(nil, value: isOn)
        }
        .accessibilityElement(children: .combine)
    }
}
