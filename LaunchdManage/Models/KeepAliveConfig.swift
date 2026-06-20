import Foundation

/// KeepAlive 配置（可以是简单 Bool 或复杂字典）
enum KeepAliveConfig: Sendable, Equatable {
    /// 简单布尔值
    case simple(Bool)
    /// 复杂条件配置
    case conditional(KeepAliveConditions)
    
    /// 是否启用 KeepAlive（任何形式）
    var isEnabled: Bool {
        switch self {
        case .simple(let value): value
        case .conditional: true
        }
    }
    
    /// 从 plist 值解析
    static func from(plistValue: Any) -> KeepAliveConfig? {
        if let boolValue = plistValue as? Bool {
            return .simple(boolValue)
        }
        if let dict = plistValue as? [String: Any] {
            return .conditional(KeepAliveConditions(from: dict))
        }
        return nil
    }
    
    /// 转换为 plist 值
    func toPlistValue() -> Any {
        switch self {
        case .simple(let value): value
        case .conditional(let conditions): conditions.toDictionary()
        }
    }
}

/// KeepAlive 的条件配置
struct KeepAliveConditions: Sendable, Equatable {
    var successfulExit: Bool?
    var crashed: Bool?
    var pathState: [String: Bool]
    var otherJobEnabled: [String: Bool]
    
    init(
        successfulExit: Bool? = nil,
        crashed: Bool? = nil,
        pathState: [String: Bool] = [:],
        otherJobEnabled: [String: Bool] = [:]
    ) {
        self.successfulExit = successfulExit
        self.crashed = crashed
        self.pathState = pathState
        self.otherJobEnabled = otherJobEnabled
    }
    
    init(from dict: [String: Any]) {
        self.successfulExit = dict["SuccessfulExit"] as? Bool
        self.crashed = dict["Crashed"] as? Bool
        self.pathState = (dict["PathState"] as? [String: Bool]) ?? [:]
        self.otherJobEnabled = (dict["OtherJobEnabled"] as? [String: Bool]) ?? [:]
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let successfulExit { dict["SuccessfulExit"] = successfulExit }
        if let crashed { dict["Crashed"] = crashed }
        if !pathState.isEmpty { dict["PathState"] = pathState }
        if !otherJobEnabled.isEmpty { dict["OtherJobEnabled"] = otherJobEnabled }
        return dict
    }
}
