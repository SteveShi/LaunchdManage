import Foundation

/// 文件监控服务，使用 DispatchSource 侦测 launchd 目录中 plist 文件的创建、修改和删除
actor FileWatcherService {
    static let shared = FileWatcherService()
    
    private var sources: [DispatchSourceFileSystemObject] = []
    private var fileDescriptors: [Int32] = []
    private var isWatching = false
    
    private init() {}
    
    /// 开始监控所有 launchd 目录
    func startWatching() {
        guard !isWatching else { return }
        isWatching = true
        
        let pathsToWatch = JobCategory.allCases.map { $0.directoryURL }
        
        for url in pathsToWatch {
            let path = url.path
            guard FileManager.default.fileExists(atPath: path) else { continue }
            
            let fd = open(path, O_EVTONLY)
            guard fd >= 0 else { continue }
            
            fileDescriptors.append(fd)
            
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: .write,
                queue: DispatchQueue.global(qos: .utility)
            )
            
            source.setEventHandler {
                // 目录内容发生变化，通过通知中心发布变更
                NotificationCenter.default.post(
                    name: .launchdDirectoriesDidChange,
                    object: nil
                )
            }
            
            source.setCancelHandler {
                close(fd)
            }
            
            source.resume()
            sources.append(source)
        }
    }
    
    /// 停止监控并释放资源
    func stopWatching() {
        guard isWatching else { return }
        isWatching = false
        
        for source in sources {
            source.cancel()
        }
        sources.removeAll()
        fileDescriptors.removeAll()
    }
    
    deinit {
        for source in sources {
            source.cancel()
        }
    }
}

extension Notification.Name {
    static let launchdDirectoriesDidChange = Notification.Name("launchdDirectoriesDidChange")
}
