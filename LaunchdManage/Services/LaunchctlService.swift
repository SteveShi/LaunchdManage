import Foundation

/// launchctl 服务状态条目
struct ServiceStatusEntry: Sendable {
    let pid: Int?
    let lastExitStatus: Int?
    let label: String
}

/// launchctl 命令封装
@MainActor
final class LaunchctlService {
    static let shared = LaunchctlService()
    
    private let shell = ShellExecutor.shared
    
    /// 获取当前用户 UID
    private var currentUID: uid_t { getuid() }
    
    /// 用户域目标
    private var userDomain: String { "gui/\(currentUID)" }
    
    // MARK: - 查询
    
    /// 列出所有已加载服务（legacy: launchctl list）
    func listLoadedServices() async throws -> [ServiceStatusEntry] {
        let result = try await shell.launchctl("list")
        guard result.isSuccess else {
            return []
        }
        
        var entries: [ServiceStatusEntry] = []
        let lines = result.stdout.components(separatedBy: "\n")
        
        // 跳过标题行
        for line in lines.dropFirst() {
            let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard parts.count >= 3 else { continue }
            
            let pid = Int(parts[0].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "-", with: ""))
            let exitStatus = Int(parts[1].trimmingCharacters(in: .whitespaces))
            let label = String(parts[2]).trimmingCharacters(in: .whitespaces)
            
            guard !label.isEmpty else { continue }
            
            entries.append(ServiceStatusEntry(
                pid: pid,
                lastExitStatus: exitStatus,
                label: label
            ))
        }
        
        return entries
    }
    
    /// 获取已禁用的服务列表
    func listDisabled(domain: String) async throws -> [String: Bool] {
        let result = try await shell.launchctl("print-disabled", domain)
        guard result.isSuccess else { return [:] }
        
        var disabled: [String: Bool] = [:]
        let lines = result.stdout.components(separatedBy: "\n")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Format: "com.example.service" => enabled/disabled
            if trimmed.contains("=>") {
                let parts = trimmed.components(separatedBy: "=>")
                if parts.count == 2 {
                    let label = parts[0]
                        .trimmingCharacters(in: .whitespaces)
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    let state = parts[1].trimmingCharacters(in: .whitespaces)
                    disabled[label] = (state == "disabled")
                }
            }
        }
        
        return disabled
    }
    
    // MARK: - 服务管理
    
    /// 加载服务 (bootstrap)
    func loadService(plistURL: URL, domain: String) async throws {
        if domain == "system" {
            try await XPCClient.shared.loadSystemService(domain: domain, plistPath: plistURL.path)
        } else {
            let result = try await shell.launchctl("bootstrap", domain, plistURL.path)
            if !result.isSuccess {
                // 如果现代命令失败，尝试 legacy
                let legacyResult = try await shell.launchctl("load", plistURL.path)
                if !legacyResult.isSuccess {
                    throw LaunchctlError.loadFailed(label: plistURL.lastPathComponent, message: legacyResult.stderr)
                }
            }
        }
    }
    
    /// 卸载服务 (bootout)
    func unloadService(domain: String, label: String) async throws {
        if domain == "system" {
            try await XPCClient.shared.unloadSystemService(domain: domain, label: label)
        } else {
            let target = "\(domain)/\(label)"
            let result = try await shell.launchctl("bootout", target)
            if !result.isSuccess {
                // 尝试 legacy
                let legacyResult = try await shell.launchctl("unload", label)
                if !legacyResult.isSuccess {
                    throw LaunchctlError.unloadFailed(label: label, message: legacyResult.stderr)
                }
            }
        }
    }
    
    /// 启用服务
    func enableService(domain: String, label: String) async throws {
        let target = "\(domain)/\(label)"
        let result = try await shell.launchctl("enable", target)
        if !result.isSuccess {
            throw LaunchctlError.enableFailed(label: label, message: result.stderr)
        }
    }
    
    /// 禁用服务
    func disableService(domain: String, label: String) async throws {
        let target = "\(domain)/\(label)"
        let result = try await shell.launchctl("disable", target)
        if !result.isSuccess {
            throw LaunchctlError.disableFailed(label: label, message: result.stderr)
        }
    }
    
    /// 强制启动 (kickstart)
    func kickstartService(domain: String, label: String, kill: Bool = false) async throws {
        let target = "\(domain)/\(label)"
        var args = ["kickstart"]
        if kill { args.append("-k") }
        args.append(target)
        
        let result = try await shell.launchctl(args)
        if !result.isSuccess {
            throw LaunchctlError.kickstartFailed(label: label, message: result.stderr)
        }
    }
    
    /// 发送信号
    func sendSignal(_ signal: Int32, domain: String, label: String) async throws {
        let target = "\(domain)/\(label)"
        let result = try await shell.launchctl("kill", String(signal), target)
        if !result.isSuccess {
            throw LaunchctlError.signalFailed(label: label, signal: signal, message: result.stderr)
        }
    }
    
    // MARK: - 便捷方法
    
    /// 重新加载服务（卸载后重新加载）
    func reloadService(plistURL: URL, domain: String, label: String) async throws {
        // 先尝试卸载，忽略错误（可能未加载）
        _ = try? await unloadService(domain: domain, label: label)
        
        // 短暂等待
        try await Task.sleep(for: .milliseconds(500))
        
        // 重新加载
        try await loadService(plistURL: plistURL, domain: domain)
    }
    
    /// 根据 LaunchdJob 获取其运行状态
    func getStatus(for job: LaunchdJob) async throws -> JobStatus {
        let services = try await listLoadedServices()
        
        if let entry = services.first(where: { $0.label == job.label }) {
            if let pid = entry.pid, pid > 0 {
                return .running(pid: pid)
            }
            if let exitStatus = entry.lastExitStatus, exitStatus != 0 {
                return .error(code: exitStatus)
            }
            return .loaded
        }
        
        return .notLoaded
    }
    
    /// 获取指定进程的系统资源占用 (CPU / 内存 % / 运行时间)
    func getProcessResourceUsage(pid: Int) async -> ProcessResourceUsage? {
        do {
            let result = try await shell.execute("/bin/ps", arguments: ["-p", String(pid), "-o", "%cpu,%mem,etime"])
            guard result.isSuccess else { return nil }
            
            let lines = result.stdout.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            guard lines.count >= 2 else { return nil }
            
            // lines[1] 包含数据，如 "0.0  0.1      20:15"
            let values = lines[1].components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
            
            guard values.count >= 3 else { return nil }
            let cpu = Double(values[0]) ?? 0.0
            let mem = Double(values[1]) ?? 0.0
            let elapsed = values[2]
            
            return ProcessResourceUsage(cpu: cpu, memory: mem, elapsed: elapsed)
        } catch {
            return nil
        }
    }
}

/// 进程资源占用结构体
struct ProcessResourceUsage: Sendable {
    let cpu: Double
    let memory: Double
    let elapsed: String
}

/// launchctl 操作错误
enum LaunchctlError: LocalizedError, Sendable {
    case loadFailed(label: String, message: String)
    case unloadFailed(label: String, message: String)
    case enableFailed(label: String, message: String)
    case disableFailed(label: String, message: String)
    case kickstartFailed(label: String, message: String)
    case signalFailed(label: String, signal: Int32, message: String)
    
    var errorDescription: String? {
        switch self {
        case .loadFailed(let label, let msg):
            String(localized: "Failed to load \(label): \(msg)")
        case .unloadFailed(let label, let msg):
            String(localized: "Failed to unload \(label): \(msg)")
        case .enableFailed(let label, let msg):
            String(localized: "Failed to enable \(label): \(msg)")
        case .disableFailed(let label, let msg):
            String(localized: "Failed to disable \(label): \(msg)")
        case .kickstartFailed(let label, let msg):
            String(localized: "Failed to kickstart \(label): \(msg)")
        case .signalFailed(let label, let signal, let msg):
            String(localized: "Failed to send signal \(signal) to \(label): \(msg)")
        }
    }
}
