import SwiftUI
import UniformTypeIdentifiers

@main
struct LaunchdManageApp: App {
    @State private var jobListViewModel = JobListViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(jobListViewModel)
        }
        .defaultSize(width: 1000, height: 650)
        .commands {
            SidebarCommands()
        }
        
        Settings {
            SettingsView()
        }
        
        WindowGroup(id: "job-editor", for: URL.self) { $url in
            if let url = $url.wrappedValue {
                SingleJobEditorView(plistURL: url)
                    .frame(minWidth: 700, minHeight: 500)
            }
        }
    }
}

/// 主内容视图
struct ContentView: View {
    @Environment(JobListViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow
    
    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationSplitView {
            SidebarView()
        } detail: {
            if let selectedID = viewModel.selectedJobID,
               let job = viewModel.jobs.first(where: { $0.id == selectedID }) {
                JobDetailView(job: job)
                    .id(job.id)
            } else {
                EmptyStateView()
            }
        }
        .navigationSplitViewColumnWidth(min: 250, ideal: 300)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .task {
            await viewModel.loadAllJobs()
            await FileWatcherService.shared.startWatching()
        }
    }
    
    // MARK: - Drag & Drop Handling
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileType = UTType.fileURL.identifier
        let providersWithURL = providers.filter { $0.hasItemConformingToTypeIdentifier(fileType) }
        guard !providersWithURL.isEmpty else { return false }
        
        Task {
            var urls: [URL] = []
            for provider in providersWithURL {
                if let url = await loadURL(from: provider) {
                    urls.append(url)
                }
            }
            
            await MainActor.run {
                handleDroppedURLs(urls)
            }
        }
        return true
    }
    
    private func loadURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                } else if let url = item as? NSURL {
                    continuation.resume(returning: url as URL)
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    continuation.resume(returning: url)
                } else {
                    _ = provider.loadObject(ofClass: URL.self) { url, error in
                        continuation.resume(returning: url)
                    }
                }
            }
        }
    }
    
    private func handleDroppedURLs(_ urls: [URL]) {
        for url in urls {
            guard url.pathExtension.lowercased() == "plist" else { continue }
            
            let standardizedPath = url.standardizedFileURL.path
            
            // 1. 先检查是否已在列表中存在
            if let matchedJob = viewModel.jobs.first(where: { $0.plistURL.standardizedFileURL.path == standardizedPath }) {
                viewModel.selectedJobID = matchedJob.id
            } else {
                // 2. 检查是否在标准 launchd 目录中
                let isStandardPath = JobCategory.allCases.contains { category in
                    standardizedPath.hasPrefix(category.directoryURL.standardizedFileURL.path)
                }
                
                if isStandardPath {
                    // 如果在标准目录，重新扫描后再定位一次
                    Task {
                        await viewModel.loadAllJobs()
                        if let newMatchedJob = viewModel.jobs.first(where: { $0.plistURL.standardizedFileURL.path == standardizedPath }) {
                            viewModel.selectedJobID = newMatchedJob.id
                        } else {
                            openWindow(id: "job-editor", value: url)
                        }
                    }
                } else {
                    // 3. 外部未知 plist 路径，使用独立窗口编辑
                    openWindow(id: "job-editor", value: url)
                }
            }
        }
    }
}
