import SwiftUI

struct DiffPanelView: View {
    let state: GitPanelState
    let onClose: () -> Void
    let onModeSelected: (DiffPanelMode) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    ForEach(DiffPanelMode.allCases, id: \.self) { mode in
                        Button(mode.title) {
                            onModeSelected(mode)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(state.mode.title)
                            .font(.system(.headline, design: .default))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
                .menuStyle(.borderlessButton)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider()
                .overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Text("\(state.summary.filesChanged) files")
                        .foregroundColor(.white.opacity(0.75))
                    Text("+\(state.summary.additions)")
                        .foregroundColor(.green)
                    Text("-\(state.summary.deletions)")
                        .foregroundColor(.red)
                }
                .font(.system(.caption, design: .monospaced))

                if let errorText = state.errorText {
                    Text(errorText)
                        .font(.system(.callout, design: .default))
                        .foregroundColor(.red.opacity(0.85))
                } else if state.patchText.isEmpty {
                    Text("Diff preview will be available in the next phase.")
                        .font(.system(.callout, design: .default))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    ScrollView {
                        Text(state.patchText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
        )
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
