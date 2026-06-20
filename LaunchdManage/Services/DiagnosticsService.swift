import Foundation

/// 诊断级别
enum DiagnosticSeverity: String, Sendable, Codable {
    case info
    case warning
    case error
}

/// 诊断条目
struct DiagnosticEntry: Sendable, Identifiable {
    var id: String { message }
    let severity: DiagnosticSeverity
    let message: String
    let suggestion: String?
    let affectedKey: String?
}

/// 智能配置诊断服务
@MainActor
final class DiagnosticsService {
    static let shared = DiagnosticsService()
    
    private init() {}
    
    /// 分析配置，返回诊断报告
    func analyze(_ job: LaunchdJob) -> [DiagnosticEntry] {
        var reports: [DiagnosticEntry] = []
        
        // 1. 验证 Label
        validateLabel(job.label, into: &reports)
        
        // 2. 验证程序路径与可执行权限
        validateProgram(job, into: &reports)
        
        // 3. 验证输出流重定向路径
        validateOutputPaths(job, into: &reports)
        
        // 4. 验证调度和 KeepAlive 冲突
        validateScheduleAndKeepAlive(job, into: &reports)
        
        return reports
    }
    
    // MARK: - 规则逻辑
    
    private func validateLabel(_ label: String, into reports: inout [DiagnosticEntry]) {
        if label.isEmpty {
            reports.append(DiagnosticEntry(
                severity: .error,
                message: String(localized: "Service Label is empty"),
                suggestion: String(localized: "Please provide a unique identifier for your service."),
                affectedKey: "Label"
            ))
            return
        }
        
        // 简易反向域名正则：类似 com.example.service
        let regex = "^[a-zA-Z0-9.-]+$"
        if label.range(of: regex, options: .regularExpression) == nil {
            reports.append(DiagnosticEntry(
                severity: .warning,
                message: String(localized: "Label contains unusual characters"),
                suggestion: String(localized: "Launchd labels should typically contain only alphanumeric characters, dots, and hyphens."),
                affectedKey: "Label"
            ))
        }
        
        if !label.contains(".") {
            reports.append(DiagnosticEntry(
                severity: .info,
                message: String(localized: "Label does not use reverse-domain format"),
                suggestion: String(localized: "It is a best practice to use reverse-domain format (e.g., com.steveshi.appname) to prevent naming collisions."),
                affectedKey: "Label"
            ))
        }
    }
    
    private func validateProgram(_ job: LaunchdJob, into reports: inout [DiagnosticEntry]) {
        let execPath: String
        let affectedKey: String
        
        if let program = job.program, !program.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            execPath = program
            affectedKey = "Program"
        } else if let firstArg = job.programArguments.first, !firstArg.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            execPath = firstArg
            affectedKey = "ProgramArguments"
        } else {
            reports.append(DiagnosticEntry(
                severity: .error,
                message: String(localized: "No executable program specified"),
                suggestion: String(localized: "You must specify either the Program path or at least one argument in ProgramArguments."),
                affectedKey: "Program"
            ))
            return
        }
        
        // 如果是相对路径
        if !execPath.hasPrefix("/") {
            reports.append(DiagnosticEntry(
                severity: .warning,
                message: String(localized: "Relative path used for program"),
                suggestion: String(localized: "launchd executes tasks from the system root domain. Using relative paths (e.g. 'myscript.sh') may fail unless WorkingDirectory is properly set."),
                affectedKey: affectedKey
            ))
        } else {
            // 绝对路径，检查是否存在
            if !FileManager.default.fileExists(atPath: execPath) {
                reports.append(DiagnosticEntry(
                    severity: .warning,
                    message: String(localized: "Executable program does not exist"),
                    suggestion: String(localized: "The path '\(execPath)' was not found on this system. Please check if the target script or application is installed."),
                    affectedKey: affectedKey
                ))
            }
        }
    }
    
    private func validateOutputPaths(_ job: LaunchdJob, into reports: inout [DiagnosticEntry]) {
        let fileManager = FileManager.default
        
        let pathsToCheck = [
            ("StandardOutPath", job.standardOutPath),
            ("StandardErrorPath", job.standardErrorPath)
        ]
        
        for (key, pathOpt) in pathsToCheck {
            guard let path = pathOpt, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            
            let url = URL(fileURLWithPath: path)
            let directoryPath = url.deletingLastPathComponent().path
            
            if !fileManager.fileExists(atPath: directoryPath) {
                reports.append(DiagnosticEntry(
                    severity: .warning,
                    message: String(localized: "Parent directory for \(key) does not exist"),
                    suggestion: String(localized: "The folder '\(directoryPath)' was not found. launchd cannot create log files if their parent directory does not exist, which will block service loading."),
                    affectedKey: key
                ))
            }
        }
    }
    
    private func validateScheduleAndKeepAlive(_ job: LaunchdJob, into reports: inout [DiagnosticEntry]) {
        let hasKeepAlive = job.keepAlive != nil
        let hasInterval = job.startInterval != nil
        
        if hasKeepAlive && hasInterval {
            reports.append(DiagnosticEntry(
                severity: .warning,
                message: String(localized: "Conflict: Both KeepAlive and StartInterval are enabled"),
                suggestion: String(localized: "KeepAlive instructs launchd to keep the process running continuously. StartInterval schedules it to launch periodically. Combining them usually yields unpredictable behavior."),
                affectedKey: "KeepAlive"
            ))
        }
    }
}
