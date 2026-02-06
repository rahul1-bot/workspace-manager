import Foundation

struct PDFPanelState: Equatable, Sendable {
    var isPresented: Bool
    var fileURL: URL?
    var fileName: String
    var currentPageIndex: Int
    var totalPages: Int
    var isLoading: Bool
    var errorText: String?

    init(
        isPresented: Bool = false,
        fileURL: URL? = nil,
        fileName: String = "",
        currentPageIndex: Int = 0,
        totalPages: Int = 0,
        isLoading: Bool = false,
        errorText: String? = nil
    ) {
        self.isPresented = isPresented
        self.fileURL = fileURL
        self.fileName = fileName
        self.currentPageIndex = currentPageIndex
        self.totalPages = totalPages
        self.isLoading = isLoading
        self.errorText = errorText
    }
}
