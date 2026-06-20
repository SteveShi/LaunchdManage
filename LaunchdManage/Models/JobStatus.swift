import Foundation

/// 服务的运行时状态
enum JobStatus: Sendable, Equatable {
    /// 正在运行，附带 PID
    case running(pid: Int)
    /// 已停止
    case stopped
    /// 已加载但未运行
    case loaded
    /// 未加载
    case notLoaded
    /// 出错，附带错误码
    case error(code: Int)
    /// 状态未知
    case unknown
    
    /// 是否正在运行
    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
    
    /// 是否已加载（包括正在运行）
    var isLoaded: Bool {
        switch self {
        case .running, .loaded, .error: true
        default: false
        }
    }
    
    /// 状态显示文本
    var displayText: String {
        switch self {
        case .running(let pid): String(localized: "Running (PID: \(pid))")
        case .stopped: String(localized: "Stopped")
        case .loaded: String(localized: "Loaded")
        case .notLoaded: String(localized: "Not Loaded")
        case .error(let code): String(localized: "Error (\(code))")
        case .unknown: String(localized: "Unknown")
        }
    }
    
    /// 状态对应的颜色名称
    var colorName: String {
        switch self {
        case .running: "green"
        case .stopped: "gray"
        case .loaded: "yellow"
        case .notLoaded: "gray"
        case .error: "red"
        case .unknown: "gray"
        }
    }
}
