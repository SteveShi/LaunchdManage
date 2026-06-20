import Foundation

/// launchd 服务的分类，对应不同的 plist 文件存放目录
enum JobCategory: String, CaseIterable, Identifiable, Sendable, Codable {
    case userAgent
    case globalAgent
    case globalDaemon
    case systemAgent
    case systemDaemon
    
    var id: String { rawValue }
    
    /// 分类显示名称
    var displayName: String {
        switch self {
        case .userAgent: String(localized: "User Agents")
        case .globalAgent: String(localized: "Global Agents")
        case .globalDaemon: String(localized: "Global Daemons")
        case .systemAgent: String(localized: "System Agents")
        case .systemDaemon: String(localized: "System Daemons")
        }
    }
    
    /// 对应的文件系统目录 URL
    var directoryURL: URL {
        switch self {
        case .userAgent:
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents")
        case .globalAgent:
            URL(fileURLWithPath: "/Library/LaunchAgents")
        case .globalDaemon:
            URL(fileURLWithPath: "/Library/LaunchDaemons")
        case .systemAgent:
            URL(fileURLWithPath: "/System/Library/LaunchAgents")
        case .systemDaemon:
            URL(fileURLWithPath: "/System/Library/LaunchDaemons")
        }
    }
    
    /// 是否受 SIP 保护（只读）
    var isSystemProtected: Bool {
        switch self {
        case .systemAgent, .systemDaemon: true
        default: false
        }
    }
    
    /// 是否需要 root 权限才能修改
    var requiresRoot: Bool {
        switch self {
        case .globalAgent, .globalDaemon, .systemAgent, .systemDaemon: true
        case .userAgent: false
        }
    }
    
    /// SF Symbol 图标名
    var symbolName: String {
        switch self {
        case .userAgent: "person.circle"
        case .globalAgent: "globe"
        case .globalDaemon: "gearshape.2"
        case .systemAgent: "apple.logo"
        case .systemDaemon: "lock.shield"
        }
    }
    
    /// launchctl 域目标前缀
    var domainTarget: String {
        switch self {
        case .userAgent, .globalAgent:
            "gui/\(getuid())"
        case .globalDaemon, .systemDaemon, .systemAgent:
            "system"
        }
    }
}
