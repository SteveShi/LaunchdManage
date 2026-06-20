import SwiftUI

struct SingleJobEditorView: View {
    let plistURL: URL
    
    @State private var job: LaunchdJob?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(String(localized: "Loading configuration..."))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = errorMessage {
                ContentUnavailableView {
                    Label(String(localized: "Load Failed"), systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                }
            } else if let job = job {
                // 复用成熟详情页面
                JobDetailView(job: job)
                    .id(job.id)
            }
        }
        .task {
            await loadJob()
        }
    }
    
    private func loadJob() async {
        isLoading = true
        errorMessage = nil
        do {
            // 根据 plist 物理路径推算分类
            let category = JobCategory.allCases.first { cat in
                plistURL.path.hasPrefix(cat.directoryURL.path)
            } ?? .userAgent
            
            // 解析 Plist 并丰富状态
            let parsedJob = try await PlistParser.shared.parse(from: plistURL, category: category)
            await JobDiscoveryService.shared.enrichWithStatus([parsedJob])
            
            await MainActor.run {
                self.job = parsedJob
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
