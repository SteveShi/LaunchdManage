import SwiftUI
import CodeEditor

/// XML 预览与编辑器（带行号和高级语法高亮）
struct XMLPreviewView: View {
    @Binding var xmlContent: String
    
    var body: some View {
        CodeEditor(
            source: $xmlContent,
            language: .xml,
            theme: .ocean,
            flags: .defaultEditorFlags
        )
    }
}
