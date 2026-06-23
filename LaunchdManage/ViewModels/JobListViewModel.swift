import Foundation
import Observation

/// 服务列表的状态筛选类型
enum FilterType: String, CaseIterable, Identifiable, Sendable {
    case all
    case running
    case notRunning
    case loaded
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .all: String(localized: "All", comment: "Filter label")
        case .running: String(localized: "Running", comment: "Filter label")
        case .notRunning: String(localized: "Not Running", comment: "Filter label")
        case .loaded: String(localized: "Loaded", comment: "Filter label")
        }
    }
}

/// 服务列表视图模型
@Observable
@MainActor
final class JobListViewModel {
    var jobs: [LaunchdJob] = []
    var selectedJobID: String?
    var searchText: String = ""
    var selectedCategories: Set<JobCategory> = Set(JobCategory.allCases)
    var isLoading: Bool = false
    var errorMessage: String?
    var selectedFilter: FilterType = .all
    
    private let discoveryService = JobDiscoveryService.shared
    private let launchctlService = LaunchctlService.shared
    
    init() {
        NotificationCenter.default.addObserver(
            forName: .launchdDirectoriesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.loadAllJobs()
            }
        }
    }
    
    /// 按搜索、分类和状态过滤后的 jobs
    var filteredJobs: [LaunchdJob] {
        jobs.filter { job in
            let matchesCategory = selectedCategories.contains(job.category)
            let matchesSearch = searchText.isEmpty || 
                job.label.localizedCaseInsensitiveContains(searchText) ||
                (job.program?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                job.programArguments.contains { $0.localizedCaseInsensitiveContains(searchText) }
            
            let matchesFilter: Bool = {
                switch selectedFilter {
                case .all: return true
                case .running: return job.status.isRunning
                case .notRunning: return !job.status.isRunning
                case .loaded: return job.status.isLoaded
                }
            }()
            
            return matchesCategory && matchesSearch && matchesFilter
        }
    }
    
    /// 按分类分组的 jobs
    var groupedJobs: [(category: JobCategory, jobs: [LaunchdJob])] {
        JobCategory.allCases.compactMap { category in
            let categoryJobs = filteredJobs
                .filter { $0.category == category }
                .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
            return categoryJobs.isEmpty ? nil : (category: category, jobs: categoryJobs)
        }
    }
    
    /// 加载所有 jobs
    func loadAllJobs() async {
        isLoading = true
        errorMessage = nil
        
        let discoveredJobs = await discoveryService.discoverAllJobs()
        await discoveryService.enrichWithStatus(discoveredJobs)
        
        jobs = discoveredJobs
        isLoading = false
    }
    
    /// 刷新所有 jobs 的运行时状态
    func refreshStatus() async {
        await discoveryService.enrichWithStatus(jobs)
    }
    
    /// 加载指定服务
    func loadService(_ job: LaunchdJob) async {
        do {
            try await launchctlService.loadService(
                plistURL: job.plistURL,
                domain: job.category.domainTarget
            )
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 卸载指定服务
    func unloadService(_ job: LaunchdJob) async {
        do {
            try await launchctlService.unloadService(
                domain: job.category.domainTarget,
                label: job.label
            )
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 启动指定服务 (kickstart)
    func startService(_ job: LaunchdJob) async {
        do {
            try await launchctlService.kickstartService(
                domain: job.category.domainTarget,
                label: job.label
            )
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 停止指定服务 (SIGTERM)
    func stopService(_ job: LaunchdJob) async {
        do {
            try await launchctlService.sendSignal(
                15, // SIGTERM
                domain: job.category.domainTarget,
                label: job.label
            )
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 启用指定服务
    func enableService(_ job: LaunchdJob) async {
        do {
            try await launchctlService.enableService(
                domain: job.category.domainTarget,
                label: job.label
            )
            job.disabled = false
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 禁用指定服务
    func disableService(_ job: LaunchdJob) async {
        do {
            try await launchctlService.disableService(
                domain: job.category.domainTarget,
                label: job.label
            )
            job.disabled = true
            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// 卸载并彻底删除指定服务（删除 plist 文件）
    func deleteJob(_ job: LaunchdJob) async throws {
        // 1. 如果已加载，先卸载
        if job.status.isLoaded {
            _ = try? await launchctlService.unloadService(
                domain: job.category.domainTarget,
                label: job.label
            )
        }
        
        // 2. 从文件系统删除 plist
        if FileManager.default.fileExists(atPath: job.plistURL.path) {
            if job.category.requiresRoot {
                try await XPCClient.shared.removePlist(atPath: job.plistURL.path)
            } else {
                try FileManager.default.removeItem(at: job.plistURL)
            }
        }
        
        // 3. 从列表中移除，并清空选中
        if selectedJobID == job.id {
            selectedJobID = nil
        }
        jobs.removeAll(where: { $0.id == job.id })
    }
}
