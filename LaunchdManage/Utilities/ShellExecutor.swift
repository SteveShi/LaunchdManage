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

        // 并发读取 stdout/stderr，避免任一管道缓冲区(~64KB)写满后子进程阻塞、
        // 父进程在另一管道上 readDataToEndOfFile 永久等待而死锁
        async let stdoutData = Self.readToEnd(stdoutPipe.fileHandleForReading)
        async let stderrData = Self.readToEnd(stderrPipe.fileHandleForReading)
        let (out, err) = await (stdoutData, stderrData)

        process.waitUntilExit()
        
        let stdout = String(data: out, encoding: .utf8) ?? ""
        let stderr = String(data: err, encoding: .utf8) ?? ""

        return CommandResult(
            stdout: stdout,
            stderr: stderr,
            exitCode: process.terminationStatus
        )
    }

    /// 在后台队列上同步读取管道直到 EOF，包装为可并发 await 的异步调用
    private static func readToEnd(_ handle: FileHandle) async -> Data {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: handle.readDataToEndOfFile())
            }
        }
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
