import Foundation

/// 提权辅助服务 XPC 接口协议
/// 注意：XPC 协议必须继承自 NSObject 协议，且由于跨进程序列化限制，
/// 方法参数不能有返回值，必须使用闭包(reply)进行回调，且参数必须是 Cocoa 兼容类型。
@objc(HelperProtocol)
protocol HelperProtocol {
    /// 以 root 权限将 plist 数据写入特定路径
    func writePlist(data: Data, toPath path: String, withReply reply: @escaping (Bool, String?) -> Void)
    
    /// 以 root 权限删除指定路径的 plist 文件
    func removePlist(atPath path: String, withReply reply: @escaping (Bool, String?) -> Void)
    
    /// 以 root 权限执行 launchctl bootstrap (加载服务)
    func loadSystemService(domain: String, plistPath: String, withReply reply: @escaping (Bool, String?) -> Void)
    
    /// 以 root 权限执行 launchctl bootout (卸载服务)
    func unloadSystemService(domain: String, label: String, withReply reply: @escaping (Bool, String?) -> Void)
    
    /// 获取当前提权服务的版本号，用以检测升级
    func getVersion(withReply reply: @escaping (String) -> Void)
}
