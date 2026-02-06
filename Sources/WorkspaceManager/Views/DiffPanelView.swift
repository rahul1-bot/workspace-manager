import SwiftUI

struct DiffPanelView: View {
    let state: GitPanelState
    let onClose: () -> Void
    let onModeSelected: (DiffPanelMode) -> Void

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .overlay(Color.white.opacity(0.08))

            VStack(alignment: .leading, spacing: 12) {
                summaryView
                contentView
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.95))
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private var patchLines: [String] {
        state.patchText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private var headerView: some View {
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
    }

    private var summaryView: some View {
        HStack(spacing: 10) {
            Text("\(state.summary.filesChanged) files")
                .foregroundColor(.white.opacity(0.75))
            Text("+\(state.summary.additions)")
                .foregroundColor(.green)
            Text("-\(state.summary.deletions)")
                .foregroundColor(.red)
        }
        .font(.system(.caption, design: .monospaced))
    }

    @ViewBuilder
    private var contentView: some View {
        if let errorText = state.errorText {
            Text(errorText)
                .font(.system(.callout, design: .default))
                .foregroundColor(.red.opacity(0.85))
        } else if state.isLoading {
            ProgressView("Loading diff…")
                .tint(.white)
                .foregroundColor(.white.opacity(0.7))
        } else if state.patchText.isEmpty {
            Text("No changes for the selected mode.")
                .font(.system(.callout, design: .default))
                .foregroundColor(.white.opacity(0.7))
        } else {
            patchContentView
        }
    }

    private var patchContentView: some View {
        ScrollView([.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(patchLines.enumerated()), id: \.offset) { _, line in
                    let lineStyle = style(for: line)
                    Text(line.isEmpty ? " " : line)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(lineStyle.foreground)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 1)
                        .background(lineStyle.background)
                }
            }
        }
        .background(Color.black)
        .textSelection(.enabled)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        )
    }

    private func style(for line: String) -> DiffLineStyle {
        if line.hasPrefix("diff --git") {
            return DiffLineStyle(foreground: Color.white.opacity(0.96), background: Color.white.opacity(0.08))
        }
        if line.hasPrefix("+++ ") || line.hasPrefix("--- ") {
            return DiffLineStyle(foreground: Color.cyan.opacity(0.95), background: Color.cyan.opacity(0.16))
        }
        if line.hasPrefix("@@") {
            return DiffLineStyle(foreground: Color.orange.opacity(0.95), background: Color.orange.opacity(0.22))
        }
        if line.hasPrefix("+"), !line.hasPrefix("+++") {
            return DiffLineStyle(foreground: Color.green.opacity(0.96), background: Color.green.opacity(0.24))
        }
        if line.hasPrefix("-"), !line.hasPrefix("---") {
            return DiffLineStyle(foreground: Color.red.opacity(0.96), background: Color.red.opacity(0.24))
        }
        if line.hasPrefix("index ") {
            return DiffLineStyle(foreground: Color.white.opacity(0.65), background: Color.white.opacity(0.02))
        }
        return DiffLineStyle(foreground: Color(red: 0.86, green: 0.89, blue: 0.94), background: .clear)
    }
}

private struct DiffLineStyle {
    let foreground: Color
    let background: Color
}
