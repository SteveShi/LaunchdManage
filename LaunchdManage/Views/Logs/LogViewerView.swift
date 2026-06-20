import SwiftUI

struct LogViewerView: View {
    @Bindable var viewModel: LogViewModel
    @AppStorage("terminalFontSize") private var terminalFontSize = 12.0
    @AppStorage("terminalTheme") private var terminalTheme = "classicGreen"
    
    var body: some View {
        VStack(spacing: 0) {
            // 工具栏过滤条
            HStack(spacing: 12) {
                Picker(selection: $viewModel.selectedSource) {
                    ForEach(LogViewModel.LogSource.allCases) { source in
                        Text(source.displayName).tag(source)
                    }
                } label: {
                    Text(String(localized: "Log Source:"))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
                
                Spacer()
                
                // 搜索/过滤输入框
                TextField(String(localized: "Filter logs..."), text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
                
                // 实时流式监控开关
                Toggle(isOn: $viewModel.isStreaming) {
                    Text(String(localized: "Stream"))
                }
                .toggleStyle(.checkbox)
                .onChange(of: viewModel.isStreaming) { _, newValue in
                    if newValue {
                        viewModel.startStreaming()
                    } else {
                        viewModel.stopStreaming()
                    }
                }
                
                // 手动刷新按钮
                Button {
                    Task {
                        await viewModel.loadLogs()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help(String(localized: "Refresh"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            Divider()
            
            // 日志内容终端面板
            if viewModel.isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(terminalBgColor)
            } else if viewModel.filteredLines.isEmpty {
                VStack {
                    Spacer()
                    Text(String(localized: "No logs found"))
                        .foregroundColor(.gray)
                        .font(.system(size: CGFloat(terminalFontSize), design: .monospaced))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(terminalBgColor)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(viewModel.filteredLines.enumerated()), id: \.offset) { index, line in
                                Text(line)
                                    .font(.system(size: CGFloat(terminalFontSize), design: .monospaced))
                                    .foregroundColor(colorForLine(line))
                                    .textSelection(.enabled)
                                    .id(index)
                            }
                        }
                        .padding(12)
                    }
                    .background(terminalBgColor)
                    .onChange(of: viewModel.filteredLines) { _, newLines in
                        if viewModel.isStreaming, let lastIndex = newLines.indices.last {
                            // 滚动到底部
                            withAnimation {
                                proxy.scrollTo(lastIndex, anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        if let lastIndex = viewModel.filteredLines.indices.last {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.loadLogs()
            }
        }
        .onDisappear {
            viewModel.stopStreaming()
        }
        .onChange(of: viewModel.selectedSource) { _, _ in
            Task {
                await viewModel.loadLogs()
            }
        }
    }
    
    private var terminalBgColor: Color {
        switch terminalTheme {
        case "monokai": return Color(red: 0.16, green: 0.16, blue: 0.15)
        case "ocean": return Color(red: 0.05, green: 0.12, blue: 0.22)
        case "classicWhite": return Color.white
        default: return Color.black
        }
    }
    
    private func colorForLine(_ line: String) -> Color {
        let isDark = terminalTheme != "classicWhite"
        
        if line.hasPrefix("[OUT]") {
            switch terminalTheme {
            case "monokai": return Color(red: 0.65, green: 0.89, blue: 0.18) // Monokai 绿
            case "ocean": return Color(red: 0.2, green: 0.8, blue: 1.0)     // 海洋青
            case "classicWhite": return Color(red: 0.0, green: 0.6, blue: 0.0) // 深绿
            default: return Color(red: 0.2, green: 0.8, blue: 0.2)          // 经典绿
            }
        } else if line.hasPrefix("[ERR]") || line.contains("Error") || line.contains("error") || line.contains("fail") || line.contains("Fail") {
            switch terminalTheme {
            case "monokai": return Color(red: 0.98, green: 0.15, blue: 0.45) // Monokai 红
            default: return Color(red: 1.0, green: 0.3, blue: 0.3)          // 经典红/深红
            }
        } else if line.contains("Warning") || line.contains("warning") {
            return Color(red: 1.0, green: 0.7, blue: 0.2) // 橙色/黄色
        }
        
        return isDark ? .white : .black
    }
}
