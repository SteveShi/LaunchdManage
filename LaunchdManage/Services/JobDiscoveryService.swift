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
        // 目录遍历与文件读取属 I/O 密集操作，放到后台线程执行，避免阻塞主线程导致界面卡顿
        let rawPlists = await Task.detached(priority: .userInitiated) {
            Self.readRawPlists()
        }.value

        // 回到主线程：反序列化并构造 MainActor 隔离的 LaunchdJob
        var allJobs: [LaunchdJob] = []
        for raw in rawPlists {
            do {
                guard let dict = try PropertyListSerialization.propertyList(
                    from: raw.data, options: [], format: nil
                ) as? [String: Any] else {
                    continue
                }
                let job = try parser.parse(from: dict, url: raw.url, category: raw.category)
                allJobs.append(job)
            } catch {
                // 跳过无法解析的 plist 文件，记录日志
                print("Warning: Failed to parse \(raw.url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return allJobs
    }

    /// 后台读取到的原始 plist 数据（全部为值类型，可安全跨线程传递）
    private struct RawPlist: Sendable {
        let url: URL
        let category: JobCategory
        let data: Data
    }

    /// 在后台线程遍历所有标准目录并读取 plist 文件原始数据
    private nonisolated static func readRawPlists() -> [RawPlist] {
        let fileManager = FileManager.default
        var result: [RawPlist] = []

        for category in JobCategory.allCases {
            let directoryURL = category.directoryURL
            guard fileManager.fileExists(atPath: directoryURL.path) else { continue }

            guard let contents = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for plistURL in contents where plistURL.pathExtension == "plist" {
                if let data = try? Data(contentsOf: plistURL) {
                    result.append(RawPlist(url: plistURL, category: category, data: data))
                }
            }
        }

        return result
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
