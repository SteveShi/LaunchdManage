import Foundation
import ServiceManagement

/// 主应用端 XPC 客户端，管理 XPC 连接并暴露系统提权服务的代理操作
@MainActor
final class XPCClient {
    static let shared = XPCClient()
    
    private var connection: NSXPCConnection?
    
    private init() {}
    
    /// 确保存在有效的 XPC 连接（不存在则建立持久连接）
    private func ensureConnection() -> NSXPCConnection {
        if let existingConnection = connection {
            return existingConnection
        }

        // 建立连接到 Mach 服务的持久 XPC 管道
        let newConnection = NSXPCConnection(machServiceName: "com.steveshi.launchdmanager.helper", options: .privileged)
        newConnection.remoteObjectInterface = NSXPCInterface(with: HelperProtocol.self)

        newConnection.invalidationHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
            }
        }
        newConnection.interruptionHandler = { [weak self] in
            Task { @MainActor in
                self?.connection = nil
            }
        }

        newConnection.resume()
        self.connection = newConnection
        return newConnection
    }

    /// 获取带错误处理回调的远端代理。
    /// 关键：必须使用 remoteObjectProxyWithErrorHandler，否则当辅助进程未安装/未授权/崩溃时，
    /// reply 回调永不触发，挂起的 continuation 永远不会 resume，导致整个提权操作永久挂起。
    private func makeProxy(errorHandler: @escaping @Sendable (Error) -> Void) throws -> HelperProtocol {
        let conn = ensureConnection()
        guard let proxy = conn.remoteObjectProxyWithErrorHandler(errorHandler) as? HelperProtocol else {
            throw NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to establish XPC connection proxy"])
        }
        return proxy
    }
    
    /// 使用 SMAppService 注册并激活特权后台守护进程
    func registerHelper() throws {
        let service = SMAppService.daemon(plistName: "com.steveshi.launchdmanager.helper.plist")
        
        switch service.status {
        case .enabled:
            return // 已启用，不需要重复动作
        case .notFound, .notRegistered, .requiresApproval:
            try service.register()
        @unknown default:
            try service.register()
        }
    }
    
    /// 使用 SMAppService 注销并清理特权后台守护进程
    func unregisterHelper() async throws {
        let service = SMAppService.daemon(plistName: "com.steveshi.launchdmanager.helper.plist")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            service.unregister { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    /// 检查特权服务的运行状态
    var helperStatus: SMAppService.Status {
        let service = SMAppService.daemon(plistName: "com.steveshi.launchdmanager.helper.plist")
        return service.status
    }
    
    // MARK: - 协议方法异步封装代理
    
    /// 提权写入 Plist
    func writePlist(data: Data, toPath path: String) async throws {
        try registerHelper()
        return try await withCheckedThrowingContinuation { continuation in
            let resumer = ContinuationResumer(continuation)
            do {
                let proxy = try makeProxy { resumer.resume(throwing: $0) }
                proxy.writePlist(data: data, toPath: path) { success, errorMsg in
                    if success {
                        resumer.resume()
                    } else {
                        resumer.resume(throwing: NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Unknown privileged write error"]))
                    }
                }
            } catch {
                resumer.resume(throwing: error)
            }
        }
    }

    /// 提权删除 Plist
    func removePlist(atPath path: String) async throws {
        try registerHelper()
        return try await withCheckedThrowingContinuation { continuation in
            let resumer = ContinuationResumer(continuation)
            do {
                let proxy = try makeProxy { resumer.resume(throwing: $0) }
                proxy.removePlist(atPath: path) { success, errorMsg in
                    if success {
                        resumer.resume()
                    } else {
                        resumer.resume(throwing: NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Unknown privileged remove error"]))
                    }
                }
            } catch {
                resumer.resume(throwing: error)
            }
        }
    }

    /// 提权载入 launchd 服务
    func loadSystemService(domain: String, plistPath: String) async throws {
        try registerHelper()
        return try await withCheckedThrowingContinuation { continuation in
            let resumer = ContinuationResumer(continuation)
            do {
                let proxy = try makeProxy { resumer.resume(throwing: $0) }
                proxy.loadSystemService(domain: domain, plistPath: plistPath) { success, errorMsg in
                    if success {
                        resumer.resume()
                    } else {
                        resumer.resume(throwing: NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Failed to bootstrap system service"]))
                    }
                }
            } catch {
                resumer.resume(throwing: error)
            }
        }
    }

    /// 提权卸载 launchd 服务
    func unloadSystemService(domain: String, label: String) async throws {
        try registerHelper()
        return try await withCheckedThrowingContinuation { continuation in
            let resumer = ContinuationResumer(continuation)
            do {
                let proxy = try makeProxy { resumer.resume(throwing: $0) }
                proxy.unloadSystemService(domain: domain, label: label) { success, errorMsg in
                    if success {
                        resumer.resume()
                    } else {
                        resumer.resume(throwing: NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Failed to bootout system service"]))
                    }
                }
            } catch {
                resumer.resume(throwing: error)
            }
        }
    }

    /// 获取特权服务的版本号
    func getVersion() async throws -> String {
        try registerHelper()
        return try await withCheckedThrowingContinuation { continuation in
            let resumer = StringContinuationResumer(continuation)
            do {
                let proxy = try makeProxy { resumer.resume(throwing: $0) }
                proxy.getVersion { version in
                    resumer.resume(returning: version)
                }
            } catch {
                resumer.resume(throwing: error)
            }
        }
    }
}

/// 一次性 continuation 包装器：当 XPC reply 回调与连接错误处理回调发生竞争时，
/// 保证只 resume 一次，避免 CheckedContinuation 因重复 resume 而触发崩溃。
private final class OneShotContinuation<T: Sendable>: @unchecked Sendable {
    private var continuation: CheckedContinuation<T, Error>?
    private let lock = NSLock()

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    private func take() -> CheckedContinuation<T, Error>? {
        lock.lock()
        defer { lock.unlock() }
        let c = continuation
        continuation = nil
        return c
    }

    func resume(returning value: T) { take()?.resume(returning: value) }
    func resume(throwing error: Error) { take()?.resume(throwing: error) }
}

extension OneShotContinuation where T == Void {
    func resume() { resume(returning: ()) }
}

private typealias ContinuationResumer = OneShotContinuation<Void>
private typealias StringContinuationResumer = OneShotContinuation<String>
