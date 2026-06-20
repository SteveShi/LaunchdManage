import Foundation

/// Plist 解析错误
enum PlistParserError: LocalizedError, Sendable {
    case fileNotFound(URL)
    case invalidFormat(URL)
    case missingLabel(URL)
    case serializationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            String(localized: "Plist file not found: \(url.path)")
        case .invalidFormat(let url):
            String(localized: "Invalid plist format: \(url.path)")
        case .missingLabel(let url):
            String(localized: "Missing Label key in plist: \(url.path)")
        case .serializationFailed(let message):
            String(localized: "Serialization failed: \(message)")
        }
    }
}

/// Plist 文件解析器
@MainActor
final class PlistParser {
    static let shared = PlistParser()
    
    /// 从 URL 解析 plist 为字典
    func parseDictionary(from url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PlistParserError.fileNotFound(url)
        }
        
        let data = try Data(contentsOf: url)
        guard let dict = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            throw PlistParserError.invalidFormat(url)
        }
        
        return dict
    }
    
    /// 从 URL 解析 plist 为 LaunchdJob
    func parse(from url: URL, category: JobCategory) throws -> LaunchdJob {
        let dict = try parseDictionary(from: url)
        return try parse(from: dict, url: url, category: category)
    }
    
    /// 从字典解析 plist 为 LaunchdJob
    func parse(from dict: [String: Any], url: URL, category: JobCategory) throws -> LaunchdJob {
        guard let label = dict["Label"] as? String else {
            throw PlistParserError.missingLabel(url)
        }
        
        // Program
        let program = dict["Program"] as? String
        let programArguments = (dict["ProgramArguments"] as? [String]) ?? []
        
        // Schedule
        let runAtLoad = (dict["RunAtLoad"] as? Bool) ?? false
        let startInterval = dict["StartInterval"] as? Int
        
        // StartCalendarInterval - 可以是单个字典或字典数组
        var calendarIntervals: [CalendarInterval] = []
        if let singleInterval = dict["StartCalendarInterval"] as? [String: Any] {
            calendarIntervals.append(CalendarInterval(from: singleInterval))
        } else if let multipleIntervals = dict["StartCalendarInterval"] as? [[String: Any]] {
            calendarIntervals = multipleIntervals.map { CalendarInterval(from: $0) }
        }
        
        let watchPaths = (dict["WatchPaths"] as? [String]) ?? []
        let queueDirectories = (dict["QueueDirectories"] as? [String]) ?? []
        
        // KeepAlive
        let keepAlive: KeepAliveConfig? = dict["KeepAlive"].flatMap { KeepAliveConfig.from(plistValue: $0) }
        
        // Environment
        let envVars = (dict["EnvironmentVariables"] as? [String: String]) ?? [:]
        let workingDir = dict["WorkingDirectory"] as? String
        let userName = dict["UserName"] as? String
        let groupName = dict["GroupName"] as? String
        let rootDirectory = dict["RootDirectory"] as? String
        let umask = dict["Umask"] as? Int
        
        // Logging
        let stdoutPath = dict["StandardOutPath"] as? String
        let stderrPath = dict["StandardErrorPath"] as? String
        
        // Process management
        let processType = (dict["ProcessType"] as? String).flatMap { ProcessType(rawValue: $0) }
        let sessionType = (dict["LimitLoadToSessionType"] as? String).flatMap { SessionType(rawValue: $0) }
        let throttleInterval = dict["ThrottleInterval"] as? Int
        let exitTimeOut = dict["ExitTimeOut"] as? Int
        let nice = dict["Nice"] as? Int
        let abandonProcessGroup = (dict["AbandonProcessGroup"] as? Bool) ?? false
        let legacyTimers = (dict["LegacyTimers"] as? Bool) ?? false
        let disabled = (dict["Disabled"] as? Bool) ?? false
        
        // Resource limits
        let softLimits = (dict["SoftResourceLimits"] as? [String: Any]).map { ResourceLimits(from: $0) } ?? ResourceLimits()
        let hardLimits = (dict["HardResourceLimits"] as? [String: Any]).map { ResourceLimits(from: $0) } ?? ResourceLimits()
        
        return LaunchdJob(
            label: label,
            category: category,
            plistURL: url,
            program: program,
            programArguments: programArguments,
            runAtLoad: runAtLoad,
            startInterval: startInterval,
            startCalendarIntervals: calendarIntervals,
            watchPaths: watchPaths,
            queueDirectories: queueDirectories,
            keepAlive: keepAlive,
            environmentVariables: envVars,
            workingDirectory: workingDir,
            userName: userName,
            groupName: groupName,
            rootDirectory: rootDirectory,
            umask: umask,
            standardOutPath: stdoutPath,
            standardErrorPath: stderrPath,
            processType: processType,
            limitLoadToSessionType: sessionType,
            throttleInterval: throttleInterval,
            exitTimeOut: exitTimeOut,
            nice: nice,
            abandonProcessGroup: abandonProcessGroup,
            legacyTimers: legacyTimers,
            disabled: disabled,
            softResourceLimits: softLimits,
            hardResourceLimits: hardLimits
        )
    }
    
    /// 将 LaunchdJob 序列化为 plist 字典
    func toDictionary(_ job: LaunchdJob) -> [String: Any] {
        var dict: [String: Any] = [:]
        
        dict["Label"] = job.label
        
        if let program = job.program { dict["Program"] = program }
        if !job.programArguments.isEmpty { dict["ProgramArguments"] = job.programArguments }
        
        if job.runAtLoad { dict["RunAtLoad"] = true }
        if let interval = job.startInterval { dict["StartInterval"] = interval }
        
        if !job.startCalendarIntervals.isEmpty {
            if job.startCalendarIntervals.count == 1 {
                dict["StartCalendarInterval"] = job.startCalendarIntervals[0].toDictionary()
            } else {
                dict["StartCalendarInterval"] = job.startCalendarIntervals.map { $0.toDictionary() }
            }
        }
        
        if !job.watchPaths.isEmpty { dict["WatchPaths"] = job.watchPaths }
        if !job.queueDirectories.isEmpty { dict["QueueDirectories"] = job.queueDirectories }
        
        if let keepAlive = job.keepAlive { dict["KeepAlive"] = keepAlive.toPlistValue() }
        
        if !job.environmentVariables.isEmpty { dict["EnvironmentVariables"] = job.environmentVariables }
        if let dir = job.workingDirectory { dict["WorkingDirectory"] = dir }
        if let user = job.userName { dict["UserName"] = user }
        if let group = job.groupName { dict["GroupName"] = group }
        if let root = job.rootDirectory { dict["RootDirectory"] = root }
        if let umask = job.umask { dict["Umask"] = umask }
        
        if let stdout = job.standardOutPath { dict["StandardOutPath"] = stdout }
        if let stderr = job.standardErrorPath { dict["StandardErrorPath"] = stderr }
        
        if let pt = job.processType { dict["ProcessType"] = pt.rawValue }
        if let st = job.limitLoadToSessionType { dict["LimitLoadToSessionType"] = st.rawValue }
        if let ti = job.throttleInterval { dict["ThrottleInterval"] = ti }
        if let et = job.exitTimeOut { dict["ExitTimeOut"] = et }
        if let nice = job.nice { dict["Nice"] = nice }
        if job.abandonProcessGroup { dict["AbandonProcessGroup"] = true }
        if job.legacyTimers { dict["LegacyTimers"] = true }
        if job.disabled { dict["Disabled"] = true }
        
        if !job.softResourceLimits.isEmpty { dict["SoftResourceLimits"] = job.softResourceLimits.toDictionary() }
        if !job.hardResourceLimits.isEmpty { dict["HardResourceLimits"] = job.hardResourceLimits.toDictionary() }
        
        return dict
    }
    
    /// 将 LaunchdJob 序列化为 plist Data
    func serialize(_ job: LaunchdJob) throws -> Data {
        let dict = toDictionary(job)
        return try PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .xml,
            options: 0
        )
    }
    
    /// 将 LaunchdJob 序列化为格式化的 XML 字符串
    func serializeToXML(_ job: LaunchdJob) throws -> String {
        let data = try serialize(job)
        guard let xml = String(data: data, encoding: .utf8) else {
            throw PlistParserError.serializationFailed(job.label)
        }
        return xml
    }
    
    /// 将 plist Data 写入文件，可选支持提权写入
    func write(_ data: Data, to url: URL, requiresRoot: Bool = false) async throws {
        if requiresRoot {
            try await XPCClient.shared.writePlist(data: data, toPath: url.path)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }
}
