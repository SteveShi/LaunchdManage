import Foundation

/// Plist 数据与 XML 字符串之间的转换工具
enum PlistSerializer {
    /// 将 plist 文件的 Data 转换为格式化的 XML 字符串
    static func dataToXMLString(_ data: Data) throws -> String {
        // 先解析为 property list 对象
        let plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        )
        
        // 重新序列化为 XML 格式
        let xmlData = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        
        guard let xmlString = String(data: xmlData, encoding: .utf8) else {
            throw PlistSerializerError.encodingFailed
        }
        
        return xmlString
    }
    
    /// 从 URL 读取 plist 文件并转换为 XML 字符串
    static func fileToXMLString(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return try dataToXMLString(data)
    }
    
    /// 将 XML 字符串解析为 plist 字典
    static func xmlStringToDictionary(_ xmlString: String) throws -> [String: Any] {
        guard let data = xmlString.data(using: .utf8) else {
            throw PlistSerializerError.encodingFailed
        }
        
        guard let dict = try PropertyListSerialization.propertyList(
            from: data,
            options: .mutableContainersAndLeaves,
            format: nil
        ) as? [String: Any] else {
            throw PlistSerializerError.invalidFormat
        }
        
        return dict
    }
}

/// 序列化错误
enum PlistSerializerError: LocalizedError, Sendable {
    case encodingFailed
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            String(localized: "Failed to encode plist data")
        case .invalidFormat:
            String(localized: "Invalid plist format")
        }
    }
}
