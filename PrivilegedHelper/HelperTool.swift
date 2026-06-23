import Foundation

/// 提权服务核心接口实现
final class HelperTool: NSObject, HelperProtocol {
    private let version = "1.0.0"

    /// 允许提权操作的目录白名单。helper 以 root 运行，必须限制其只能改写
    /// launchd 目录下的 .plist，避免（被滥用或因 App 端 bug）改写任意系统文件如 /etc/sudoers
    private static let allowedDirectories = ["/Library/LaunchDaemons", "/Library/LaunchAgents"]

    /// 校验目标路径：标准化后必须位于白名单目录内且以 .plist 结尾（standardized 会解析掉 ".." 防目录穿越）
    private static func isPathAllowed(_ path: String) -> Bool {
        let standardized = URL(fileURLWithPath: path).standardizedFileURL.path
        guard standardized.hasSuffix(".plist") else { return false }
        return allowedDirectories.contains { standardized.hasPrefix($0 + "/") }
    }

    func getVersion(withReply reply: @escaping (String) -> Void) {
        reply(version)
    }

    func writePlist(data: Data, toPath path: String, withReply reply: @escaping (Bool, String?) -> Void) {
        guard Self.isPathAllowed(path) else {
            reply(false, "Refused: path is outside the allowed launchd directories")
            return
        }
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
        guard Self.isPathAllowed(path) else {
            reply(false, "Refused: path is outside the allowed launchd directories")
            return
        }
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

            // 在 waitUntilExit 之前并发抽干两个管道：若 launchctl 输出超过管道缓冲区(~64KB)，
            // 子进程会阻塞在写操作而永不退出，导致 waitUntilExit 永久挂起
            let errBox = DataBox()
            let group = DispatchGroup()
            group.enter()
            DispatchQueue.global(qos: .utility).async {
                errBox.data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                group.leave()
            }
            _ = outputPipe.fileHandleForReading.readDataToEndOfFile() // 抽干 stdout，防止其写满阻塞
            group.wait()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return (true, nil)
            } else {
                let errorStr = String(data: errBox.data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let msg = errorStr ?? "Exit code: \(process.terminationStatus)"
                return (false, msg)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

/// 跨线程传递管道读取结果的简易容器；通过 DispatchGroup 建立 happens-before 关系，无并发访问
private final class DataBox: @unchecked Sendable {
    var data = Data()
}
