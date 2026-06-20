import Foundation

/// 提权服务 XPC 连接代理
final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // 1. 配置协议接口
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)
        
        // 2. 注入核心特权方法实现对象
        let exportedObject = HelperTool()
        newConnection.exportedObject = exportedObject
        
        // 3. 开启 XPC 连接
        newConnection.resume()
        return true
    }
}

// 初始化 XPC Listener，指向注册的 Mach 管道名称
let delegate = HelperDelegate()
let listener = NSXPCListener(machServiceName: "com.steveshi.launchdmanage.helper")
listener.delegate = delegate
listener.resume()

// 挂起命令行主线程以保持特权守护进程驻留运行
dispatchMain()
