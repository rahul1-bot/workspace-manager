import Foundation

struct PDFTab: Identifiable, Equatable, Sendable {
    let id: UUID
    var fileURL: URL
    var fileName: String
    var currentPageIndex: Int
    var totalPages: Int

    init(
        id: UUID = UUID(),
        fileURL: URL,
        currentPageIndex: Int = 0,
        totalPages: Int = 0
    ) {
        self.id = id
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
        self.currentPageIndex = currentPageIndex
        self.totalPages = totalPages
    }
}

struct PDFPanelState: Equatable, Sendable {
    var isPresented: Bool
    var tabs: [PDFTab]
    var activeTabId: UUID?
    var isLoading: Bool
    var errorText: String?

    init(
        isPresented: Bool = false,
        tabs: [PDFTab] = [],
        activeTabId: UUID? = nil,
        isLoading: Bool = false,
        errorText: String? = nil
    ) {
        self.isPresented = isPresented
        self.tabs = tabs
        self.activeTabId = activeTabId
        self.isLoading = isLoading
        self.errorText = errorText
    }

    var activeTab: PDFTab? {
        guard let activeTabId else { return nil }
        return tabs.first { $0.id == activeTabId }
    }

    var activeTabIndex: Int? {
        guard let activeTabId else { return nil }
        return tabs.firstIndex { $0.id == activeTabId }
    }
}
