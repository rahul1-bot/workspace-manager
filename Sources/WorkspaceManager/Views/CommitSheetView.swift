import SwiftUI

struct CommitSheetView: View {
    let state: CommitSheetState
    let onMessageChanged: (String) -> Void
    let onIncludeUnstagedChanged: (Bool) -> Void
    let onNextStepChanged: (CommitNextStep) -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Commit your changes")
                .font(.system(size: 30, weight: .bold, design: .default))
                .foregroundColor(.white)

            HStack(spacing: 12) {
                Text("Branch")
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text(state.summary.branchName)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundColor(.white.opacity(0.9))
            }

            HStack(spacing: 12) {
                Text("Changes")
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                Text("\(state.summary.filesChanged) files")
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.white.opacity(0.75))
                Text("+\(state.summary.additions)")
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.green)
                Text("-\(state.summary.deletions)")
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.red)
            }

            Toggle(isOn: Binding(get: { state.includeUnstaged }, set: onIncludeUnstagedChanged)) {
                Text("Include unstaged")
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.white)
            }
            .toggleStyle(.switch)

            VStack(alignment: .leading, spacing: 8) {
                Text("Commit message")
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.white)
                TextField(
                    "Leave blank to autogenerate a commit message",
                    text: Binding(get: { state.message }, set: onMessageChanged),
                    axis: .vertical
                )
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(minHeight: 64)
                .background(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Next steps")
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.white)

                Picker("Next steps", selection: Binding(get: { state.nextStep }, set: onNextStepChanged)) {
                    ForEach(CommitNextStep.allCases, id: \.self) { step in
                        Text(step.title).tag(step)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .tint(.white)
            }

            if let errorText = state.errorText {
                Text(errorText)
                    .font(.system(.callout, design: .default))
                    .foregroundColor(.red.opacity(0.85))
            }

            Button(action: onContinue) {
                HStack(spacing: 8) {
                    if state.isLoading {
                        ProgressView()
                            .tint(.black)
                    }
                    Text("Continue")
                        .font(.system(.headline, design: .default))
                        .foregroundColor(.black)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(state.isLoading)
        }
        .padding(20)
        .frame(width: 640)
        .background(
            VisualEffectBackground(material: .hudWindow, blendingMode: .withinWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
    }
}
