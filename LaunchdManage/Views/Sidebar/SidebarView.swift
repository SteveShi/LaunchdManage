import SwiftUI

/// 侧边栏视图
struct SidebarView: View {
    @Environment(JobListViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("showSystemServices") private var showSystemServices = true
    @AppStorage("hideDisabledServices") private var hideDisabledServices = false
    @State private var expandedCategories: Set<JobCategory> = Set(JobCategory.allCases)
    
    // MARK: - 新建与删除状态
    @State private var showingNewJobSheet = false
    @State private var jobToDelete: LaunchdJob? = nil
    @State private var showingDeleteAlert = false
    
    private func isExpandedBinding(for category: JobCategory) -> Binding<Bool> {
        Binding(
            get: { expandedCategories.contains(category) },
            set: { isExpanded in
                if isExpanded {
                    expandedCategories.insert(category)
                } else {
                    expandedCategories.remove(category)
                }
            }
        )
    }
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        VStack(spacing: 0) {
            // 快捷状态筛选栏
            HStack(spacing: 6) {
                ForEach(FilterType.allCases) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        HStack(spacing: 5) {
                            if filter != .all {
                                Circle()
                                    .fill(circleColor(for: filter))
                                    .frame(width: 6, height: 6)
                            }
                            Text(filter.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            viewModel.selectedFilter == filter
                            ? Color.primary.opacity(0.12)
                            : Color.primary.opacity(0.04)
                        )
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            List(selection: $viewModel.selectedJobID) {
            if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading Services...", comment: "Sidebar loading indicator")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(filteredGroupedJobs, id: \.category) { group in
                    Section(isExpanded: isExpandedBinding(for: group.category)) {
                        ForEach(group.jobs) { job in
                            JobRowView(job: job)
                                .tag(job.id)
                                .contextMenu {
                                    jobContextMenu(for: job)
                                }
                        }
                    } header: {
                        CategoryHeaderView(
                            category: group.category,
                            count: group.jobs.count
                        )
                    }
                }
            }
        }
        } // 闭合 VStack
        .searchable(
            text: Bindable(viewModel).searchText,
            prompt: Text("Search Services", comment: "Search field placeholder")
        )
        .toolbar {
            ToolbarItemGroup {
                // 新建服务按钮
                Button {
                    showingNewJobSheet = true
                } label: {
                    Label(
                        String(localized: "New Service", comment: "New button"),
                        systemImage: "plus"
                    )
                }
                .help(String(localized: "Create a new service", comment: "New button tooltip"))
                .keyboardShortcut("n", modifiers: .command)
                
                // 刷新列表按钮
                Button {
                    Task {
                        await viewModel.loadAllJobs()
                    }
                } label: {
                    Label(
                        String(localized: "Refresh", comment: "Refresh button"),
                        systemImage: "arrow.clockwise"
                    )
                }
                .help(String(localized: "Refresh service list", comment: "Refresh button tooltip"))
                .keyboardShortcut("r", modifiers: .command)
            }
        }
        .navigationTitle(String(localized: "Services", comment: "Sidebar navigation title"))
        
        // MARK: - 弹窗 Sheet 和 警告框
        .sheet(isPresented: $showingNewJobSheet) {
            NewJobView {
                Task {
                    await viewModel.loadAllJobs()
                }
            }
        }
        .alert(
            String(localized: "Delete Service", comment: "Alert title"),
            isPresented: $showingDeleteAlert,
            presenting: jobToDelete
        ) { job in
            Button(String(localized: "Delete", comment: "Alert action"), role: .destructive) {
                Task {
                    do {
                        try await viewModel.deleteJob(job)
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
            }
            Button(String(localized: "Cancel", comment: "Alert action"), role: .cancel) {}
        } message: { job in
            Text("Are you sure you want to delete '\(job.label)'? This will stop the service and permanently delete its configuration file.", comment: "Delete confirmation message")
        }
    }
    
    private var filteredGroupedJobs: [(category: JobCategory, jobs: [LaunchdJob])] {
        viewModel.groupedJobs.compactMap { group in
            if !showSystemServices && group.category.isSystemProtected {
                return nil
            }
            
            let jobs = group.jobs.filter { job in
                if hideDisabledServices && job.disabled {
                    return false
                }
                return true
            }
            
            return jobs.isEmpty ? nil : (category: group.category, jobs: jobs)
        }
    }
    
    @ViewBuilder
    private func jobContextMenu(for job: LaunchdJob) -> some View {
        if job.status.isLoaded {
            Button(String(localized: "Unload", comment: "Context menu action")) {
                Task { await viewModel.unloadService(job) }
            }
        } else {
            Button(String(localized: "Load", comment: "Context menu action")) {
                Task { await viewModel.loadService(job) }
            }
        }
        
        Divider()
        
        Button(String(localized: "Reveal in Finder", comment: "Context menu action")) {
            NSWorkspace.shared.selectFile(
                job.plistURL.path,
                inFileViewerRootedAtPath: job.plistURL.deletingLastPathComponent().path
            )
        }
        
        Button(String(localized: "Open in New Window", comment: "Context menu action")) {
            openWindow(id: "job-editor", value: job.plistURL)
        }
        
        Divider()
        
        Button(role: .destructive) {
            jobToDelete = job
            showingDeleteAlert = true
        } label: {
            Label(String(localized: "Delete", comment: "Context menu action"), systemImage: "trash")
        }
    }
    
    private func circleColor(for filter: FilterType) -> Color {
        switch filter {
        case .all: return .clear
        case .running: return .green
        case .notRunning: return .orange
        case .loaded: return .blue
        }
    }
}
