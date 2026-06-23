import Foundation
import Observation

/// 服务详情编辑视图模型
@Observable
@MainActor
final class JobDetailViewModel {
    let job: LaunchdJob
    
    // MARK: - 草稿数据属性
    var label: String
    var category: JobCategory
    var plistURL: URL
    
    var program: String
    var programArguments: [String]
    
    var runAtLoad: Bool
    var startInterval: Int?
    var startIntervalEnabled: Bool
    var startCalendarIntervals: [CalendarInterval]
    var watchPaths: [String]
    var queueDirectories: [String]
    
    var keepAlive: KeepAliveConfig?
    var keepAliveEnabled: Bool
    
    var environmentVariables: [String: String]
    var workingDirectory: String
    var userName: String
    var groupName: String
    var rootDirectory: String
    var umask: String
    
    var standardOutPath: String
    var standardErrorPath: String
    
    var processType: ProcessType?
    var limitLoadToSessionType: SessionType?
    var throttleInterval: Int?
    var throttleIntervalEnabled: Bool
    var exitTimeOut: Int?
    var exitTimeOutEnabled: Bool
    var nice: Int?
    var niceEnabled: Bool
    var abandonProcessGroup: Bool
    var legacyTimers: Bool
    var disabled: Bool
    
    var softResourceLimits: ResourceLimits
    var hardResourceLimits: ResourceLimits
    
    var validationErrors: [String] = []
    var isSaving: Bool = false
    var isCreation: Bool = false
    
    init(job: LaunchdJob) {
        self.job = job
        self.label = job.label
        self.category = job.category
        self.plistURL = job.plistURL
        self.program = job.program ?? ""
        self.programArguments = job.programArguments
        self.runAtLoad = job.runAtLoad
        self.startInterval = job.startInterval
        self.startIntervalEnabled = job.startInterval != nil
        self.startCalendarIntervals = job.startCalendarIntervals
        self.watchPaths = job.watchPaths
        self.queueDirectories = job.queueDirectories
        self.keepAlive = job.keepAlive
        self.keepAliveEnabled = job.keepAlive != nil
        self.environmentVariables = job.environmentVariables
        self.workingDirectory = job.workingDirectory ?? ""
        self.userName = job.userName ?? ""
        self.groupName = job.groupName ?? ""
        self.rootDirectory = job.rootDirectory ?? ""
        self.umask = job.umask.map { String(format: "%o", $0) } ?? ""
        self.standardOutPath = job.standardOutPath ?? ""
        self.standardErrorPath = job.standardErrorPath ?? ""
        self.processType = job.processType
        self.limitLoadToSessionType = job.limitLoadToSessionType
        self.throttleInterval = job.throttleInterval
        self.throttleIntervalEnabled = job.throttleInterval != nil
        self.exitTimeOut = job.exitTimeOut
        self.exitTimeOutEnabled = job.exitTimeOut != nil
        self.nice = job.nice
        self.niceEnabled = job.nice != nil
        self.abandonProcessGroup = job.abandonProcessGroup
        self.legacyTimers = job.legacyTimers
        self.disabled = job.disabled
        self.softResourceLimits = job.softResourceLimits
        self.hardResourceLimits = job.hardResourceLimits
    }
    
    /// 检查草稿与原数据相比是否有改动
    var isDirty: Bool {
        if label != job.label { return true }
        if category != job.category { return true }
        if plistURL != job.plistURL { return true }
        if program != (job.program ?? "") { return true }
        if programArguments != job.programArguments { return true }
        if runAtLoad != job.runAtLoad { return true }
        
        let targetInterval = startIntervalEnabled ? startInterval : nil
        if targetInterval != job.startInterval { return true }
        
        if startCalendarIntervals != job.startCalendarIntervals { return true }
        if watchPaths != job.watchPaths { return true }
        if queueDirectories != job.queueDirectories { return true }
        
        let jobHasKeepAlive = job.keepAlive != nil
        if keepAliveEnabled != jobHasKeepAlive { return true }
        if keepAliveEnabled, keepAlive != job.keepAlive { return true }
        
        if environmentVariables != job.environmentVariables { return true }
        if workingDirectory != (job.workingDirectory ?? "") { return true }
        if userName != (job.userName ?? "") { return true }
        if groupName != (job.groupName ?? "") { return true }
        if rootDirectory != (job.rootDirectory ?? "") { return true }
        
        let currentUmask = Int(umask, radix: 8)
        if currentUmask != job.umask { return true }
        
        if standardOutPath != (job.standardOutPath ?? "") { return true }
        if standardErrorPath != (job.standardErrorPath ?? "") { return true }
        if processType != job.processType { return true }
        if limitLoadToSessionType != job.limitLoadToSessionType { return true }
        
        let targetThrottle = throttleIntervalEnabled ? throttleInterval : nil
        if targetThrottle != job.throttleInterval { return true }
        
        let targetExitTimeout = exitTimeOutEnabled ? exitTimeOut : nil
        if targetExitTimeout != job.exitTimeOut { return true }
        
        let targetNice = niceEnabled ? nice : nil
        if targetNice != job.nice { return true }
        
        if abandonProcessGroup != job.abandonProcessGroup { return true }
        if legacyTimers != job.legacyTimers { return true }
        if disabled != job.disabled { return true }
        if softResourceLimits != job.softResourceLimits { return true }
        if hardResourceLimits != job.hardResourceLimits { return true }
        
        return false
    }
    
    /// 重置草稿为原始数据
    func revert() {
        self.label = job.label
        self.category = job.category
        self.plistURL = job.plistURL
        self.program = job.program ?? ""
        self.programArguments = job.programArguments
        self.runAtLoad = job.runAtLoad
        self.startInterval = job.startInterval
        self.startIntervalEnabled = job.startInterval != nil
        self.startCalendarIntervals = job.startCalendarIntervals
        self.watchPaths = job.watchPaths
        self.queueDirectories = job.queueDirectories
        self.keepAlive = job.keepAlive
        self.keepAliveEnabled = job.keepAlive != nil
        self.environmentVariables = job.environmentVariables
        self.workingDirectory = job.workingDirectory ?? ""
        self.userName = job.userName ?? ""
        self.groupName = job.groupName ?? ""
        self.rootDirectory = job.rootDirectory ?? ""
        self.umask = job.umask.map { String(format: "%o", $0) } ?? ""
        self.standardOutPath = job.standardOutPath ?? ""
        self.standardErrorPath = job.standardErrorPath ?? ""
        self.processType = job.processType
        self.limitLoadToSessionType = job.limitLoadToSessionType
        self.throttleInterval = job.throttleInterval
        self.throttleIntervalEnabled = job.throttleInterval != nil
        self.exitTimeOut = job.exitTimeOut
        self.exitTimeOutEnabled = job.exitTimeOut != nil
        self.nice = job.nice
        self.niceEnabled = job.nice != nil
        self.abandonProcessGroup = job.abandonProcessGroup
        self.legacyTimers = job.legacyTimers
        self.disabled = job.disabled
        self.softResourceLimits = job.softResourceLimits
        self.hardResourceLimits = job.hardResourceLimits
        self.validationErrors = []
    }
    
    convenience init(creatingInCategory category: JobCategory) {
        let defaultLabel = "com.steveshi.untitled"
        let tempURL = category.directoryURL.appendingPathComponent("\(defaultLabel).plist")
        let tempJob = LaunchdJob(label: defaultLabel, category: category, plistURL: tempURL)
        
        self.init(job: tempJob)
        self.label = ""
        self.isCreation = true
    }
    
    /// 校验表单参数
    func validate() -> Bool {
        validationErrors = []
        if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append(String(localized: "Label cannot be empty"))
        }
        if program.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && programArguments.isEmpty {
            validationErrors.append(String(localized: "Must specify Program or ProgramArguments"))
        }
        return validationErrors.isEmpty
    }
    
    /// 保存并重载服务
    func save() async throws {
        guard validate() else {
            throw NSError(
                domain: "JobDetailViewModel",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: validationErrors.joined(separator: "\n")]
            )
        }
        
        isSaving = true
        defer { isSaving = false }
        
        if isCreation {
            let finalURL = category.directoryURL.appendingPathComponent("\(label.trimmingCharacters(in: .whitespacesAndNewlines)).plist")
            // 防止新建时静默覆盖同名已存在的配置（否则会清空他人现有的 job）
            if FileManager.default.fileExists(atPath: finalURL.path) {
                throw NSError(
                    domain: "JobDetailViewModel",
                    code: 409,
                    userInfo: [NSLocalizedDescriptionKey: String(localized: "A configuration with this label already exists")]
                )
            }
            self.plistURL = finalURL
            job.plistURL = finalURL
        }
        
        // 1. 同步数据回原 job
        job.label = label
        job.category = category
        job.plistURL = plistURL
        job.program = program.isEmpty ? nil : program
        job.programArguments = programArguments
        job.runAtLoad = runAtLoad
        job.startInterval = startIntervalEnabled ? startInterval : nil
        job.startCalendarIntervals = startCalendarIntervals
        job.watchPaths = watchPaths
        job.queueDirectories = queueDirectories
        job.keepAlive = keepAliveEnabled ? (keepAlive ?? .simple(true)) : nil
        job.environmentVariables = environmentVariables
        job.workingDirectory = workingDirectory.isEmpty ? nil : workingDirectory
        job.userName = userName.isEmpty ? nil : userName
        job.groupName = groupName.isEmpty ? nil : groupName
        job.rootDirectory = rootDirectory.isEmpty ? nil : rootDirectory
        job.umask = Int(umask, radix: 8)
        job.standardOutPath = standardOutPath.isEmpty ? nil : standardOutPath
        job.standardErrorPath = standardErrorPath.isEmpty ? nil : standardErrorPath
        job.processType = processType
        job.limitLoadToSessionType = limitLoadToSessionType
        job.throttleInterval = throttleIntervalEnabled ? throttleInterval : nil
        job.exitTimeOut = exitTimeOutEnabled ? exitTimeOut : nil
        job.nice = niceEnabled ? nice : nil
        job.abandonProcessGroup = abandonProcessGroup
        job.legacyTimers = legacyTimers
        job.disabled = disabled
        job.softResourceLimits = softResourceLimits
        job.hardResourceLimits = hardResourceLimits
        
        // 2. 写入 plist 文件
        let data = try PlistParser.shared.serialize(job)
        try await PlistParser.shared.write(data, to: job.plistURL, requiresRoot: job.category.requiresRoot)
        
        // 3. 触发系统级重载
        try await LaunchctlService.shared.reloadService(
            plistURL: job.plistURL,
            domain: job.category.domainTarget,
            label: job.label
        )
    }
    
    /// 根据当前草稿的数据生成临时的 XML 字符串
    func generateDraftXML() throws -> String {
        let tempJob = LaunchdJob(
            label: label,
            category: category,
            plistURL: plistURL,
            program: program.isEmpty ? nil : program,
            programArguments: programArguments,
            runAtLoad: runAtLoad,
            startInterval: startIntervalEnabled ? startInterval : nil,
            startCalendarIntervals: startCalendarIntervals,
            watchPaths: watchPaths,
            queueDirectories: queueDirectories,
            keepAlive: keepAliveEnabled ? (keepAlive ?? .simple(true)) : nil,
            environmentVariables: environmentVariables,
            workingDirectory: workingDirectory.isEmpty ? nil : workingDirectory,
            userName: userName.isEmpty ? nil : userName,
            groupName: groupName.isEmpty ? nil : groupName,
            rootDirectory: rootDirectory.isEmpty ? nil : rootDirectory,
            umask: Int(umask, radix: 8),
            standardOutPath: standardOutPath.isEmpty ? nil : standardOutPath,
            standardErrorPath: standardErrorPath.isEmpty ? nil : standardErrorPath,
            processType: processType,
            limitLoadToSessionType: limitLoadToSessionType,
            throttleInterval: throttleIntervalEnabled ? throttleInterval : nil,
            exitTimeOut: exitTimeOutEnabled ? exitTimeOut : nil,
            nice: niceEnabled ? nice : nil,
            abandonProcessGroup: abandonProcessGroup,
            legacyTimers: legacyTimers,
            disabled: disabled,
            softResourceLimits: softResourceLimits,
            hardResourceLimits: hardResourceLimits
        )
        return try PlistParser.shared.serializeToXML(tempJob)
    }
    
    /// 从外部编辑好的 XML 字符串反向更新当前草稿的属性
    func applyXML(_ xmlString: String) throws {
        let dict = try PlistSerializer.xmlStringToDictionary(xmlString)
        let parsedJob = try PlistParser.shared.parse(from: dict, url: plistURL, category: category)
        
        // 还原至草稿属性
        self.label = parsedJob.label
        self.category = parsedJob.category
        self.plistURL = parsedJob.plistURL
        self.program = parsedJob.program ?? ""
        self.programArguments = parsedJob.programArguments
        self.runAtLoad = parsedJob.runAtLoad
        self.startInterval = parsedJob.startInterval
        self.startIntervalEnabled = parsedJob.startInterval != nil
        self.startCalendarIntervals = parsedJob.startCalendarIntervals
        self.watchPaths = parsedJob.watchPaths
        self.queueDirectories = parsedJob.queueDirectories
        self.keepAlive = parsedJob.keepAlive
        self.keepAliveEnabled = parsedJob.keepAlive != nil
        self.environmentVariables = parsedJob.environmentVariables
        self.workingDirectory = parsedJob.workingDirectory ?? ""
        self.userName = parsedJob.userName ?? ""
        self.groupName = parsedJob.groupName ?? ""
        self.rootDirectory = parsedJob.rootDirectory ?? ""
        self.umask = parsedJob.umask.map { String(format: "%o", $0) } ?? ""
        self.standardOutPath = parsedJob.standardOutPath ?? ""
        self.standardErrorPath = parsedJob.standardErrorPath ?? ""
        self.processType = parsedJob.processType
        self.limitLoadToSessionType = parsedJob.limitLoadToSessionType
        self.throttleInterval = parsedJob.throttleInterval
        self.throttleIntervalEnabled = parsedJob.throttleInterval != nil
        self.exitTimeOut = parsedJob.exitTimeOut
        self.exitTimeOutEnabled = parsedJob.exitTimeOut != nil
        self.nice = parsedJob.nice
        self.niceEnabled = parsedJob.nice != nil
        self.abandonProcessGroup = parsedJob.abandonProcessGroup
        self.legacyTimers = parsedJob.legacyTimers
        self.disabled = parsedJob.disabled
        self.softResourceLimits = parsedJob.softResourceLimits
        self.hardResourceLimits = parsedJob.hardResourceLimits
    }
}
