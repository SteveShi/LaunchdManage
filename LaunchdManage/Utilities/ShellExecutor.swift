import Foundation

/// Shell 命令执行结果
struct CommandResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32
    
    var isSuccess: Bool { exitCode == 0 }
}

/// 安全的 Shell 命令执行器
actor ShellExecutor {
    static let shared = ShellExecutor()
    
    /// 执行命令并返回结果
    func execute(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil
    ) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        if let environment {
            process.environment = environment
        }
        
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        
        try process.run()
        
        // Read output asynchronously
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        
        process.waitUntilExit()
        
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        
        return CommandResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    }
    
    /// 执行 launchctl 命令
    func launchctl(_ arguments: String...) async throws -> CommandResult {
        try await execute("/bin/launchctl", arguments: Array(arguments))
    }
    
    /// 执行 launchctl 命令（数组形式）
    func launchctl(_ arguments: [String]) async throws -> CommandResult {
        try await execute("/bin/launchctl", arguments: arguments)
    }
}
