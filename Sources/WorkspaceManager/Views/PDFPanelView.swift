import SwiftUI
import PDFKit

struct PDFPanelView: View {
    let state: PDFPanelState
    let isResizing: Bool
    let onClose: () -> Void
    let onPageChanged: (Int) -> Void

    @State private var localPageIndex: Int = 0
    @State private var localTotalPages: Int = 0

    private enum ChromeStyle {
        static let outerStrokeOpacity: Double = 0.12
        static let dividerOpacity: Double = 0.08
        static let darkOverlayOpacity: Double = 0.45
        static let headerFillOpacity: Double = 0.04
        static let navBarFillOpacity: Double = 0.04
        static let resizingFillOpacity: Double = 0.45
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider()
                .overlay(Color.white.opacity(ChromeStyle.dividerOpacity))

            navigationBar

            Divider()
                .overlay(Color.white.opacity(ChromeStyle.dividerOpacity))

            contentView
        }
        .frame(maxHeight: .infinity)
        .background(panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(Color.white.opacity(ChromeStyle.outerStrokeOpacity), lineWidth: 1)
        )
        .onChange(of: localPageIndex) { _, newIndex in
            onPageChanged(newIndex)
        }
        .onChange(of: state.currentPageIndex) { _, newIndex in
            if localPageIndex != newIndex {
                localPageIndex = newIndex
            }
        }
        .onChange(of: state.totalPages) { _, newTotal in
            localTotalPages = newTotal
        }
    }

    private var panelBackground: some View {
        ZStack {
            if isResizing {
                Color.black.opacity(ChromeStyle.resizingFillOpacity)
            } else {
                VisualEffectBackground(material: .hudWindow, blendingMode: .behindWindow)
                Color.black.opacity(ChromeStyle.darkOverlayOpacity)
            }
        }
    }

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "doc.text")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                Text(state.fileName.isEmpty ? "PDF Viewer" : state.fileName)
                    .font(.system(.headline, design: .default))
                    .foregroundColor(.white.opacity(0.95))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            pageIndicator

            Spacer()
                .frame(width: 12)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(ChromeStyle.headerFillOpacity))
    }

    private var pageIndicator: some View {
        Group {
            if localTotalPages > 0 {
                Text("\(localPageIndex + 1) / \(localTotalPages)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
    }

    private var navigationBar: some View {
        HStack(spacing: 12) {
            Button(action: goToPreviousPage) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(canGoPrevious ? .white.opacity(0.85) : .white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(!canGoPrevious)

            Button(action: goToNextPage) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(canGoNext ? .white.opacity(0.85) : .white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(!canGoNext)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(ChromeStyle.navBarFillOpacity))
    }

    @ViewBuilder
    private var contentView: some View {
        if let errorText = state.errorText {
            VStack {
                Text(errorText)
                    .font(.system(.callout, design: .default))
                    .foregroundColor(.red.opacity(0.85))
                    .padding(14)
                Spacer()
            }
        } else if state.isLoading {
            VStack {
                ProgressView("Loading PDF…")
                    .tint(.white)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(14)
                Spacer()
            }
        } else if state.fileURL == nil {
            emptyStateView
        } else if isResizing {
            resizingPlaceholderView
        } else {
            PDFViewWrapper(
                fileURL: state.fileURL,
                currentPageIndex: $localPageIndex,
                totalPages: $localTotalPages
            )
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.3))

            Text("No PDF loaded")
                .font(.system(.body, design: .default))
                .foregroundColor(.white.opacity(0.5))

            Text("⌘⇧P to open a PDF file")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white.opacity(0.4))

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var resizingPlaceholderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Resizing panel", systemImage: "arrow.left.and.right")
                .font(.system(.footnote, design: .monospaced))
                .foregroundColor(.white.opacity(0.72))

            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: index == 0 ? 24 : 18)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.black.opacity(0.25))
    }

    private var canGoPrevious: Bool {
        localPageIndex > 0
    }

    private var canGoNext: Bool {
        localTotalPages > 0 && localPageIndex < localTotalPages - 1
    }

    private func goToPreviousPage() {
        guard canGoPrevious else { return }
        localPageIndex -= 1
    }

    private func goToNextPage() {
        guard canGoNext else { return }
        localPageIndex += 1
    }
}
