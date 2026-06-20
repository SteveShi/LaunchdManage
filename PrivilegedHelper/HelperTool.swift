import Foundation

/// 提权服务核心接口实现
final class HelperTool: NSObject, HelperProtocol {
    private let version = "1.0.0"
    
    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply(version)
    }
    
    func writePlist(data: Data, toPath path: String, withReply reply: @escaping (Bool, String?) -> Void) {
        do {
            let url = URL(fileURLWithPath: path)
            // 确保父目录存在
            let parentDir = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            
            // 写入 plist 配置文件
            try data.write(to: url, options: .atomic)
            
            // 修正特权 plist 权限（必须是 root:wheel 与 644 属性，否则 launchd 会因为不安全权限而拒绝加载）
            let pathCString = path.cString(using: .utf8)
            chown(pathCString, 0, 0) // 设置所有者为 root, 组为 wheel
            chmod(pathCString, S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH) // 设置文件属性为 644 (rw-r--r--)
            
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }
    
    func removePlist(atPath path: String, withReply reply: @escaping (Bool, String?) -> Void) {
        do {
            if FileManager.default.fileExists(atPath: path) {
                try FileManager.default.removeItem(atPath: path)
            }
            reply(true, nil)
        } catch {
            reply(false, error.localizedDescription)
        }
    }
    
    func loadSystemService(domain: String, plistPath: String, withReply reply: @escaping (Bool, String?) -> Void) {
        // 执行 launchctl bootstrap <domainTarget> <plistPath>
        let result = runLaunchctl(arguments: ["bootstrap", domain, plistPath])
        reply(result.0, result.1)
    }
    
    func unloadSystemService(domain: String, label: String, withReply reply: @escaping (Bool, String?) -> Void) {
        // 执行 launchctl bootout <domainTarget>/<label>
        let target = "\(domain)/\(label)"
        let result = runLaunchctl(arguments: ["bootout", target])
        reply(result.0, result.1)
    }
    
    // MARK: - 辅助方法
    private func runLaunchctl(arguments: [String]) -> (Bool, String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                return (true, nil)
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorStr = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let msg = errorStr ?? "Exit code: \(process.terminationStatus)"
                return (false, msg)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
