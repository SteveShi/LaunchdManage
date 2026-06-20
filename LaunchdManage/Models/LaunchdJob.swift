import Foundation
import Observation

/// 进程类型
enum ProcessType: String, Sendable, CaseIterable {
    case background = "Background"
    case standard = "Standard"
    case adaptive = "Adaptive"
    case interactive = "Interactive"
}

/// 会话类型限制
enum SessionType: String, Sendable, CaseIterable {
    case aqua = "Aqua"
    case loginWindow = "LoginWindow"
    case background = "Background"
    case standardIO = "StandardIO"
    case system = "System"
}

/// 资源限制配置
struct ResourceLimits: Sendable, Equatable {
    var core: Int?
    var cpu: Int?
    var data: Int?
    var fileSize: Int?
    var memoryLock: Int?
    var numberOfFiles: Int?
    var numberOfProcesses: Int?
    var residentSetSize: Int?
    var stack: Int?
    
    init() {}
    
    init(from dict: [String: Any]) {
        self.core = dict["Core"] as? Int
        self.cpu = dict["CPU"] as? Int
        self.data = dict["Data"] as? Int
        self.fileSize = dict["FileSize"] as? Int
        self.memoryLock = dict["MemoryLock"] as? Int
        self.numberOfFiles = dict["NumberOfFiles"] as? Int
        self.numberOfProcesses = dict["NumberOfProcesses"] as? Int
        self.residentSetSize = dict["ResidentSetSize"] as? Int
        self.stack = dict["Stack"] as? Int
    }
    
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let core { dict["Core"] = core }
        if let cpu { dict["CPU"] = cpu }
        if let data { dict["Data"] = data }
        if let fileSize { dict["FileSize"] = fileSize }
        if let memoryLock { dict["MemoryLock"] = memoryLock }
        if let numberOfFiles { dict["NumberOfFiles"] = numberOfFiles }
        if let numberOfProcesses { dict["NumberOfProcesses"] = numberOfProcesses }
        if let residentSetSize { dict["ResidentSetSize"] = residentSetSize }
        if let stack { dict["Stack"] = stack }
        return dict
    }
    
    var isEmpty: Bool {
        core == nil && cpu == nil && data == nil && fileSize == nil &&
        memoryLock == nil && numberOfFiles == nil && numberOfProcesses == nil &&
        residentSetSize == nil && stack == nil
    }
}

/// 表示一个 launchd job 的完整配置
@Observable
@MainActor
final class LaunchdJob: Identifiable {
    /// 唯一标识（等同于 Label）
    let id: String
    
    // MARK: - 基础标识
    var label: String
    var category: JobCategory
    var plistURL: URL
    
    // MARK: - 程序配置
    var program: String?
    var programArguments: [String]
    
    // MARK: - 调度配置
    var runAtLoad: Bool
    var startInterval: Int?
    var startCalendarIntervals: [CalendarInterval]
    var watchPaths: [String]
    var queueDirectories: [String]
    
    // MARK: - 存活配置
    var keepAlive: KeepAliveConfig?
    
    // MARK: - 环境配置
    var environmentVariables: [String: String]
    var workingDirectory: String?
    var userName: String?
    var groupName: String?
    var rootDirectory: String?
    var umask: Int?
    
    // MARK: - 日志配置
    var standardOutPath: String?
    var standardErrorPath: String?
    
    // MARK: - 进程管理
    var processType: ProcessType?
    var limitLoadToSessionType: SessionType?
    var throttleInterval: Int?
    var exitTimeOut: Int?
    var nice: Int?
    var abandonProcessGroup: Bool
    var legacyTimers: Bool
    var disabled: Bool
    
    // MARK: - 资源限制
    var softResourceLimits: ResourceLimits
    var hardResourceLimits: ResourceLimits
    
    // MARK: - 运行时状态（不来自 plist）
    @ObservationIgnored
    var status: JobStatus = .unknown
    @ObservationIgnored
    var lastExitCode: Int?
    
    init(
        label: String,
        category: JobCategory,
        plistURL: URL,
        program: String? = nil,
        programArguments: [String] = [],
        runAtLoad: Bool = false,
        startInterval: Int? = nil,
        startCalendarIntervals: [CalendarInterval] = [],
        watchPaths: [String] = [],
        queueDirectories: [String] = [],
        keepAlive: KeepAliveConfig? = nil,
        environmentVariables: [String: String] = [:],
        workingDirectory: String? = nil,
        userName: String? = nil,
        groupName: String? = nil,
        rootDirectory: String? = nil,
        umask: Int? = nil,
        standardOutPath: String? = nil,
        standardErrorPath: String? = nil,
        processType: ProcessType? = nil,
        limitLoadToSessionType: SessionType? = nil,
        throttleInterval: Int? = nil,
        exitTimeOut: Int? = nil,
        nice: Int? = nil,
        abandonProcessGroup: Bool = false,
        legacyTimers: Bool = false,
        disabled: Bool = false,
        softResourceLimits: ResourceLimits = ResourceLimits(),
        hardResourceLimits: ResourceLimits = ResourceLimits()
    ) {
        self.id = label
        self.label = label
        self.category = category
        self.plistURL = plistURL
        self.program = program
        self.programArguments = programArguments
        self.runAtLoad = runAtLoad
        self.startInterval = startInterval
        self.startCalendarIntervals = startCalendarIntervals
        self.watchPaths = watchPaths
        self.queueDirectories = queueDirectories
        self.keepAlive = keepAlive
        self.environmentVariables = environmentVariables
        self.workingDirectory = workingDirectory
        self.userName = userName
        self.groupName = groupName
        self.rootDirectory = rootDirectory
        self.umask = umask
        self.standardOutPath = standardOutPath
        self.standardErrorPath = standardErrorPath
        self.processType = processType
        self.limitLoadToSessionType = limitLoadToSessionType
        self.throttleInterval = throttleInterval
        self.exitTimeOut = exitTimeOut
        self.nice = nice
        self.abandonProcessGroup = abandonProcessGroup
        self.legacyTimers = legacyTimers
        self.disabled = disabled
        self.softResourceLimits = softResourceLimits
        self.hardResourceLimits = hardResourceLimits
    }
}
