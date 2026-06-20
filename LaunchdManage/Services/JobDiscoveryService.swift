import Foundation

/// 服务发现错误
enum JobDiscoveryError: LocalizedError, Sendable {
    case directoryNotAccessible(String)
    
    var errorDescription: String? {
        switch self {
        case .directoryNotAccessible(let path):
            String(localized: "Directory not accessible: \(path)")
        }
    }
}

/// 服务发现与扫描
@MainActor
final class JobDiscoveryService {
    static let shared = JobDiscoveryService()
    
    private let parser = PlistParser.shared
    private let launchctl = LaunchctlService.shared
    
    /// 扫描所有标准目录，返回发现的所有 job
    func discoverAllJobs() async -> [LaunchdJob] {
        var allJobs: [LaunchdJob] = []
        
        for category in JobCategory.allCases {
            let jobs = await discoverJobs(in: category)
            allJobs.append(contentsOf: jobs)
        }
        
        return allJobs
    }
    
    /// 扫描特定类别的 job
    func discoverJobs(in category: JobCategory) async -> [LaunchdJob] {
        let directoryURL = category.directoryURL
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }
        
        guard let contents = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        let plistFiles = contents.filter { $0.pathExtension == "plist" }
        
        var jobs: [LaunchdJob] = []
        for plistURL in plistFiles {
            do {
                let job = try parser.parse(from: plistURL, category: category)
                jobs.append(job)
            } catch {
                // 跳过无法解析的 plist 文件，记录日志
                print("Warning: Failed to parse \(plistURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        return jobs
    }
    
    /// 为 jobs 填充运行时状态信息
    func enrichWithStatus(_ jobs: [LaunchdJob]) async {
        do {
            let loadedServices = try await launchctl.listLoadedServices()
            let serviceMap = Dictionary(loadedServices.map { ($0.label, $0) }, uniquingKeysWith: { first, _ in first })
            
            for job in jobs {
                if let entry = serviceMap[job.label] {
                    if let pid = entry.pid, pid > 0 {
                        job.status = .running(pid: pid)
                    } else if let exitStatus = entry.lastExitStatus, exitStatus != 0 {
                        job.status = .error(code: exitStatus)
                    } else {
                        job.status = .loaded
                    }
                    job.lastExitCode = entry.lastExitStatus
                } else {
                    job.status = .notLoaded
                }
            }
        } catch {
            // 状态查询失败时保持 unknown
            print("Warning: Failed to query service status: \(error.localizedDescription)")
        }
    }
}
