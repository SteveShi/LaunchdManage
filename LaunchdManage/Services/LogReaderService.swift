import Foundation

/// 日志读取服务，支持高效读取 Plist 输出日志以及系统统一日志 (Unified Log)
actor LogReaderService {
    static let shared = LogReaderService()
    
    private init() {}
    
    /// 从指定路径读取最后 linesCount 行日志（使用 FileHandle 高效指针反向定位，适合读取大日志文件）
    func readLogFile(path: String, linesCount: Int = 200) throws -> [String] {
        guard FileManager.default.fileExists(atPath: path) else { return [] }
        let fileURL = URL(fileURLWithPath: path)
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer { try? fileHandle.close() }
        
        let fileSize = try fileHandle.seekToEnd()
        var position = fileSize
        var lines: [String] = []
        var buffer = Data()
        
        let chunkSize = 4096
        while position > 0 && lines.count < linesCount {
            let readSize = min(chunkSize, Int(position))
            position -= UInt64(readSize)
            try fileHandle.seek(toOffset: position)
            let data = fileHandle.readData(ofLength: readSize)
            
            buffer.insert(contentsOf: data, at: 0)
            
            // 将 buffer 尝试解码，分离换行符
            if let str = String(data: buffer, encoding: .utf8) {
                let split = str.components(separatedBy: .newlines)
                if split.count > 1 {
                    // split.first 是尚未读取完整的头部，保留到 buffer 供下次继续
                    let finishedLines = split.dropFirst()
                    lines.insert(contentsOf: finishedLines.map { String($0) }, at: 0)
                    if let first = split.first, let remainingData = first.data(using: .utf8) {
                        buffer = remainingData
                    } else {
                        buffer = Data()
                    }
                }
            }
        }
        
        // 处理最后残留的头部数据
        if !buffer.isEmpty, let finalStr = String(data: buffer, encoding: .utf8) {
            lines.insert(finalStr, at: 0)
        }
        
        return Array(lines.suffix(linesCount))
    }
    
    /// 从系统 Unified Log 中查询特定服务进程的日志
    func readUnifiedLog(processName: String, timeInterval: TimeInterval = 600) async throws -> [String] {
        let shell = ShellExecutor.shared
        // 根据时间间隔折算为分钟
        let lastMinutes = max(1, Int(timeInterval / 60))
        
        let result = try await shell.execute("/usr/bin/log", arguments: [
            "show",
            "--predicate", "process == \"\(processName)\"",
            "--style", "syslog",
            "--last", "\(lastMinutes)m"
        ])
        
        guard result.isSuccess else {
            throw NSError(domain: "LogReaderService", code: 500, userInfo: [NSLocalizedDescriptionKey: result.stderr])
        }
        
        let lines = result.stdout.components(separatedBy: "\n")
        return lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
