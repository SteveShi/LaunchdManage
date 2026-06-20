import Foundation
import Observation

/// 日志查看视图模型
@Observable
@MainActor
final class LogViewModel {
    var logLines: [String] = []
    var searchText: String = ""
    var selectedSource: LogSource = .combined
    var isStreaming: Bool = false
    var isLoading: Bool = false
    
    enum LogSource: String, CaseIterable, Identifiable, Sendable {
        case combined
        case stdout
        case stderr
        case system
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .combined: String(localized: "Combined")
            case .stdout: "Stdout"
            case .stderr: "Stderr"
            case .system: String(localized: "System Log")
            }
        }
    }
    
    private let job: LaunchdJob
    private var streamTimer: Timer?
    
    init(job: LaunchdJob) {
        self.job = job
    }
    
    /// 搜索过滤后的日志行
    var filteredLines: [String] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return logLines
        }
        return logLines.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }
    
    /// 载入日志
    func loadLogs() async {
        if !isStreaming {
            isLoading = true
        }
        defer { isLoading = false }
        
        var lines: [String] = []
        
        switch selectedSource {
        case .combined:
            let outPath = job.standardOutPath ?? ""
            let errPath = job.standardErrorPath ?? ""
            
            let outLines = (try? await LogReaderService.shared.readLogFile(path: outPath)) ?? []
            let errLines = (try? await LogReaderService.shared.readLogFile(path: errPath)) ?? []
            
            lines = outLines.map { "[OUT] \($0)" } + errLines.map { "[ERR] \($0)" }
        case .stdout:
            if let stdout = job.standardOutPath, !stdout.isEmpty {
                lines = (try? await LogReaderService.shared.readLogFile(path: stdout)) ?? []
            } else {
                lines = [String(localized: "No standard output redirection configured.")]
            }
        case .stderr:
            if let stderr = job.standardErrorPath, !stderr.isEmpty {
                lines = (try? await LogReaderService.shared.readLogFile(path: stderr)) ?? []
            } else {
                lines = [String(localized: "No standard error redirection configured.")]
            }
        case .system:
            // 采用 plist 中指定的执行文件名，或者用 label 后缀进行 syslog 检索
            let procName = job.program?.components(separatedBy: "/").last ?? job.label
            lines = (try? await LogReaderService.shared.readUnifiedLog(processName: procName)) ?? []
        }
        
        self.logLines = lines
    }
    
    /// 启动实时日志监控
    func startStreaming() {
        guard !isStreaming else { return }
        isStreaming = true
        
        // 1.5 秒轮询一次最新文件，更新日志
        streamTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isStreaming else { return }
                await self.loadLogs()
            }
        }
    }
    
    /// 停止实时日志监控
    func stopStreaming() {
        isStreaming = false
        streamTimer?.invalidate()
        streamTimer = nil
    }
}
