import SwiftUI

struct CommitSheetView: View {
    let state: CommitSheetState
    let onMessageChanged: (String) -> Void
    let onIncludeUnstagedChanged: (Bool) -> Void
    let onNextStepChanged: (CommitNextStep) -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerSection

            sectionDivider

            infoSection

            sectionDivider

            messageSection

            sectionDivider

            nextStepsSection

            sectionDivider

            footerSection
        }
        .frame(width: 640)
        .background(
            ZStack {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(0.45)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.08))
    }

    private var headerSection: some View {
        HStack {
            Text("Commit your changes")
                .font(.system(size: 18, weight: .semibold, design: .default))
                .foregroundColor(.white.opacity(0.95))

            Spacer()

            Text("Esc")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.55))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text("Branch")
                    .font(.system(.body, design: .default))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text(state.summary.branchName)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }

            HStack(spacing: 12) {
                Text("Changes")
                    .font(.system(.body, design: .default))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("\(state.summary.filesChanged) files")
                    .font(.system(.body, design: .default))
                    .foregroundColor(.white.opacity(0.55))
                Text("+\(state.summary.additions)")
                    .font(.system(.body, design: .default))
                    .foregroundColor(.green)
                Text("-\(state.summary.deletions)")
                    .font(.system(.body, design: .default))
                    .foregroundColor(.red)
            }

            HStack {
                Text("Include unstaged")
                    .font(.system(.body, design: .default))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Toggle(isOn: Binding(get: { state.includeUnstaged }, set: onIncludeUnstagedChanged)) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Commit message")
                .font(.system(.body, design: .default))
                .foregroundColor(.white.opacity(0.7))

            TextField(
                "Leave blank to autogenerate a commit message",
                text: Binding(get: { state.message }, set: onMessageChanged),
                axis: .vertical
            )
            .textFieldStyle(.plain)
            .font(.system(.body, design: .default))
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .foregroundColor(.white)
            .background(Color.black.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var nextStepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Next steps")
                .font(.system(.body, design: .default))
                .foregroundColor(.white.opacity(0.7))

            ForEach(CommitNextStep.allCases, id: \.self) { step in
                Button { onNextStepChanged(step) } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(state.nextStep == step ? Color.white.opacity(0.9) : Color.clear)
                            .frame(width: 10, height: 10)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(state.nextStep == step ? 0.9 : 0.4), lineWidth: 1.5)
                            )
                        Text(step.title)
                            .font(.system(.body, design: .default))
                            .foregroundColor(.white.opacity(state.nextStep == step ? 0.95 : 0.65))
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            if let errorText = state.errorText {
                Text(errorText)
                    .font(.system(.callout, design: .default))
                    .foregroundColor(.red.opacity(0.85))
            }

            Button(action: onContinue) {
                HStack(spacing: 8) {
                    if state.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text("Continue")
                        .font(.system(.headline, design: .default))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(state.isLoading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
