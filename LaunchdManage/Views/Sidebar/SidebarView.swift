import SwiftUI

/// 侧边栏视图
struct SidebarView: View {
    @Environment(JobListViewModel.self) private var viewModel
    @AppStorage("showSystemServices") private var showSystemServices = true
    
    var body: some View {
        List(selection: selectedCategoryBinding) {
            ForEach(visibleCategories) { category in
                Label {
                    HStack {
                        Text(category.displayName)
                        Spacer()
                        if let count = viewModel.categoryCounts[category], count > 0 {
                            Text(count, format: .number)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: category.symbolName)
                }
                .tag(category)
            }
        }
        .navigationTitle(String(localized: "Categories", comment: "Sidebar navigation title"))
        .onChange(of: showSystemServices, initial: true) { _, isShowing in
            if !isShowing && viewModel.selectedCategory.isSystemProtected {
                viewModel.selectedCategory = .userAgent
            }
        }
    }
    
    private var visibleCategories: [JobCategory] {
        JobCategory.allCases.filter { category in
            showSystemServices || !category.isSystemProtected
        }
    }
    
    private var selectedCategoryBinding: Binding<JobCategory?> {
        Binding {
            viewModel.selectedCategory
        } set: { category in
            if let category {
                viewModel.selectedCategory = category
                viewModel.clearSelectionIfNeeded()
            }
        }
    }
}

/// 服务列表列视图
struct JobListView: View {
    @Environment(JobListViewModel.self) private var viewModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage("hideDisabledServices") private var hideDisabledServices = false
    
    // MARK: - 新建与删除状态
    @State private var showingNewJobSheet = false
    @State private var jobToDelete: LaunchdJob? = nil
    @State private var showingDeleteAlert = false
    
    var body: some View {
        @Bindable var viewModel = viewModel
        
        VStack(spacing: 0) {
            statusFilterBar
            
            List(selection: $viewModel.selectedJobID) {
                if viewModel.isLoading {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Loading Services...", comment: "Service list loading indicator")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ForEach(filteredJobs) { job in
                        JobRowView(job: job)
                            .tag(job.id)
                            .contextMenu {
                                jobContextMenu(for: job)
                            }
                    }
                }
            }
            .listStyle(.plain)
        }
        .searchable(
            text: $viewModel.searchText,
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
        .navigationTitle(viewModel.selectedCategory.displayName)
        .sheet(isPresented: $showingNewJobSheet) {
            NewJobView(defaultCategory: viewModel.selectedCategory) {
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
    
    private var statusFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(FilterType.allCases) { filter in
                    Button {
                        viewModel.selectedFilter = filter
                    } label: {
                        HStack(spacing: 8) {
                            if filter != .all {
                                Circle()
                                    .fill(color(for: filter))
                                    .frame(width: 7, height: 7)
                            }
                            
                            Text(filter.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(viewModel.selectedFilter == filter ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.06))
                        )
                        .overlay(
                            Capsule()
                                .stroke(viewModel.selectedFilter == filter ? Color.accentColor.opacity(0.65) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .onChange(of: viewModel.selectedFilter) { _, _ in
            viewModel.clearSelectionIfNeeded()
        }
    }
    
    private var filteredJobs: [LaunchdJob] {
        viewModel.sortedFilteredJobs.filter { job in
            !(hideDisabledServices && job.disabled)
        }
    }
    
    private func color(for filter: FilterType) -> Color {
        switch filter {
        case .all: .accentColor
        case .running: .green
        case .notRunning: .orange
        case .loaded: .blue
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
}
