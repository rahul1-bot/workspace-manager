import SwiftUI
import PDFKit

struct PDFViewWrapper: NSViewRepresentable {
    let fileURL: URL?
    @Binding var currentPageIndex: Int
    @Binding var totalPages: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        pdfView.interpolationQuality = .high

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageDidChange(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        let currentDocURL = context.coordinator.loadedURL

        guard fileURL != currentDocURL else {
            syncPageNavigation(pdfView: pdfView, coordinator: context.coordinator)
            return
        }

        context.coordinator.loadedURL = fileURL

        guard let fileURL else {
            pdfView.document = nil
            DispatchQueue.main.async {
                totalPages = 0
                currentPageIndex = 0
            }
            return
        }

        guard let document = PDFDocument(url: fileURL) else {
            DispatchQueue.main.async {
                totalPages = 0
                currentPageIndex = 0
            }
            return
        }

        pdfView.document = document
        pdfView.layoutDocumentView()

        let pageCount = document.pageCount
        DispatchQueue.main.async {
            totalPages = pageCount
            currentPageIndex = 0
        }

        context.coordinator.isSyncingPage = false
    }

    private func syncPageNavigation(pdfView: PDFView, coordinator: Coordinator) {
        guard !coordinator.isSyncingPage else { return }
        guard let document = pdfView.document else { return }

        let targetIndex = min(max(currentPageIndex, 0), document.pageCount - 1)
        guard let currentPage = pdfView.currentPage else { return }

        let currentIndex = document.index(for: currentPage)
        guard currentIndex != targetIndex else { return }

        guard let targetPage = document.page(at: targetIndex) else { return }
        coordinator.isSyncingPage = true
        pdfView.go(to: targetPage)
        coordinator.isSyncingPage = false
    }

    final class Coordinator: NSObject {
        private let parent: PDFViewWrapper
        var loadedURL: URL?
        var isSyncingPage: Bool = false

        init(parent: PDFViewWrapper) {
            self.parent = parent
        }

        @objc func pageDidChange(_ notification: Notification) {
            guard !isSyncingPage else { return }
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let document = pdfView.document else {
                return
            }

            let pageIndex = document.index(for: currentPage)
            isSyncingPage = true
            DispatchQueue.main.async { [weak self] in
                self?.parent.currentPageIndex = pageIndex
                self?.isSyncingPage = false
            }
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }
    }
}
