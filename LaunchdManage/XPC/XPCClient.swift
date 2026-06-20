import Foundation
import ServiceManagement

/// 主应用端 XPC 客户端，管理 XPC 连接并暴露系统提权服务的代理操作
@MainActor
final class XPCClient {
    static let shared = XPCClient()
    
    private var connection: NSXPCConnection?
    
    private init() {}
    
    /// 获取当前 XPC 连接代理
    private func getProxy() throws -> HelperProtocol {
        if let existingConnection = connection {
            if let proxy = existingConnection.remoteObjectProxy as? HelperProtocol {
                return proxy
            }
        }
        
        // 建立连接到 Mach 服务的持久 XPC 管道
        let newConnection = NSXPCConnection(machServiceName: "com.steveshi.launchdmanage.helper", options: .privileged)
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
        
        guard let proxy = newConnection.remoteObjectProxy as? HelperProtocol else {
            throw NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to establish XPC connection proxy"])
        }
        return proxy
    }
    
    /// 使用 SMAppService 注册并激活特权后台守护进程
    func registerHelper() throws {
        let service = SMAppService.daemon(plistName: "com.steveshi.launchdmanage.helper.plist")
        
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
        let service = SMAppService.daemon(plistName: "com.steveshi.launchdmanage.helper.plist")
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
        let service = SMAppService.daemon(plistName: "com.steveshi.launchdmanage.helper.plist")
        return service.status
    }
    
    // MARK: - 协议方法异步封装代理
    
    /// 提权写入 Plist
    func writePlist(data: Data, toPath path: String) async throws {
        try registerHelper()
        let proxy = try getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.writePlist(data: data, toPath: path) { success, errorMsg in
                if success {
                    continuation.resume()
                } else {
                    let err = NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Unknown privileged write error"])
                    continuation.resume(throwing: err)
                }
            }
        }
    }
    
    /// 提权删除 Plist
    func removePlist(atPath path: String) async throws {
        try registerHelper()
        let proxy = try getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.removePlist(atPath: path) { success, errorMsg in
                if success {
                    continuation.resume()
                } else {
                    let err = NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Unknown privileged remove error"])
                    continuation.resume(throwing: err)
                }
            }
        }
    }
    
    /// 提权载入 launchd 服务
    func loadSystemService(domain: String, plistPath: String) async throws {
        try registerHelper()
        let proxy = try getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.loadSystemService(domain: domain, plistPath: plistPath) { success, errorMsg in
                if success {
                    continuation.resume()
                } else {
                    let err = NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Failed to bootstrap system service"])
                    continuation.resume(throwing: err)
                }
            }
        }
    }
    
    /// 提权卸载 launchd 服务
    func unloadSystemService(domain: String, label: String) async throws {
        try registerHelper()
        let proxy = try getProxy()
        
        return try await withCheckedThrowingContinuation { continuation in
            proxy.unloadSystemService(domain: domain, label: label) { success, errorMsg in
                if success {
                    continuation.resume()
                } else {
                    let err = NSError(domain: "XPCClient", code: 500, userInfo: [NSLocalizedDescriptionKey: errorMsg ?? "Failed to bootout system service"])
                    continuation.resume(throwing: err)
                }
            }
        }
    }
    
    /// 获取特权服务的版本号
    func getVersion() async throws -> String {
        try registerHelper()
        let proxy = try getProxy()
        
        return await withCheckedContinuation { continuation in
            proxy.getVersion { version in
                continuation.resume(returning: version)
            }
        }
    }
}
