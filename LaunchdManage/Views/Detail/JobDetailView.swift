import SwiftUI

/// 服务详情主视图
struct JobDetailView: View {
    let job: LaunchdJob
    
    @State private var viewModel: JobDetailViewModel
    @State private var logViewModel: LogViewModel
    @State private var selectedTab: DetailTab = .editor
    @State private var xmlContent: String = ""
    @State private var xmlBeforeEditing: String = ""
    /// 磁盘上 plist 的 XML 基准内容，用于判断脏状态，避免每次渲染都同步读盘
    @State private var diskXML: String = ""
    /// 诊断结果缓存，避免每次渲染都重新分析
    @State private var diagnostics: [DiagnosticEntry] = []
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showInspector = false
    @Environment(JobListViewModel.self) private var listViewModel
    @State private var codeMode = false
    
    init(job: LaunchdJob) {
        self.job = job
        self._viewModel = State(wrappedValue: JobDetailViewModel(job: job))
        self._logViewModel = State(wrappedValue: LogViewModel(job: job))
    }
    
    enum DetailTab: String, CaseIterable {
        case editor
        case logs
        
        var label: String {
            switch self {
            case .editor: String(localized: "Editor", comment: "Detail tab")
            case .logs: String(localized: "Logs", comment: "Detail tab")
            }
        }
        
        var icon: String {
            switch self {
            case .editor: "slider.horizontal.3"
            case .logs: "terminal"
            }
        }
    }
    
    /// 检查当前视图是否处于脏状态（有修改未保存）
    private var hasChanges: Bool {
        // 代码模式下与磁盘基准比较；基准在 loadXML 时缓存，不在渲染期读盘
        codeMode ? (xmlContent != diskXML) : viewModel.isDirty
    }

    var body: some View {
        VStack(spacing: 0) {
            // 头部基本信息面板
            VStack(alignment: .leading, spacing: 8) {
                Text(job.label)
                    .font(.title2)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                
                Text(job.plistURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                
                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: job.category.symbolName)
                        Text(job.category.displayName)
                    }
                    .foregroundStyle(.secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.fill")
                        Text(job.status.isLoaded ? String(localized: "Loaded", comment: "Status label") : String(localized: "Not Loaded", comment: "Status label"))
                    }
                    .foregroundStyle(job.status.isLoaded ? .blue : .secondary)
                    
                    HStack(spacing: 6) {
                        Image(systemName: job.disabled ? "xmark.circle" : "checkmark.circle")
                        Text(job.disabled ? String(localized: "Disabled", comment: "Status label") : String(localized: "Enabled", comment: "Status label"))
                    }
                    .foregroundStyle(job.disabled ? .orange : .green)
                    
                    HStack(spacing: 6) {
                        Image(systemName: job.status.isRunning ? "play.circle" : "stop.circle")
                        Text(runningStatusText)
                    }
                    .foregroundStyle(job.status.isRunning ? .green : .orange)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Tab 选择器与辅助按钮区
            HStack {
                Picker(selection: $selectedTab) {
                    ForEach(DetailTab.allCases, id: \.self) { tab in
                        Label(tab.label, systemImage: tab.icon)
                            .tag(tab)
                    }
                } label: {
                    EmptyView()
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
                
                Spacer()
                
                if selectedTab == .editor {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            codeMode.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .padding(6)
                            .background(codeMode ? Color.accentColor.opacity(0.15) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Toggle XML Code View"))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            
            // Tab 内容
            ZStack(alignment: .bottom) {
                switch selectedTab {
                case .editor:
                    VStack(spacing: 0) {
                        if !diagnostics.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(diagnostics) { diag in
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: diag.iconName)
                                            .font(.headline)
                                            .foregroundStyle(diag.color)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(diag.message)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            if let suggestion = diag.suggestion {
                                                Text(suggestion)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(diag.backgroundColor)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(diag.strokeColor, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            
                            Divider()
                        }
                        
                        if codeMode {
                            XMLPreviewView(xmlContent: $xmlContent)
                        } else {
                            FormEditorView(viewModel: viewModel)
                        }
                    }
                case .logs:
                    LogViewerView(viewModel: logViewModel)
                }
                
                // 悬浮保存操作面板
                if hasChanges {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("You have unsaved changes", comment: "Unsaved changes notification text")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(String(localized: "Revert", comment: "Button label")) {
                            revertChanges()
                        }
                        
                        Button(String(localized: "Apply", comment: "Button label")) {
                            Task { await applyChanges() }
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut("s", modifiers: .command)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
        .alert(
            String(localized: "Error", comment: "Alert title"),
            isPresented: $showErrorAlert,
            actions: { Button(String(localized: "OK", comment: "Button label"), role: .cancel) {} },
            message: { Text(errorMessage ?? "") }
        )
        .task(id: job.id) {
            await loadXML()
            diagnostics = DiagnosticsService.shared.analyze(job)
        }
        .inspector(isPresented: $showInspector) {
            StatusDashboard(job: job)
        }
        .onChange(of: codeMode) { oldValue, newValue in
            if newValue {
                if viewModel.isDirty {
                    if let draftXML = try? viewModel.generateDraftXML() {
                        xmlContent = draftXML
                    }
                } else {
                    if let originalXML = try? PlistSerializer.fileToXMLString(job.plistURL) {
                        xmlContent = originalXML
                        diskXML = originalXML
                    }
                }
                xmlBeforeEditing = xmlContent
            } else {
                if xmlContent != xmlBeforeEditing {
                    do {
                        try viewModel.applyXML(xmlContent)
                    } catch {
                        errorMessage = String(localized: "Failed to sync XML back to form: \(error.localizedDescription)")
                        showErrorAlert = true
                        codeMode = true
                    }
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            if oldValue == .logs {
                logViewModel.stopStreaming()
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                ToolbarButtonsView(job: job)
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label(String(localized: "Toggle Inspector"), systemImage: "sidebar.right")
                }
                .help(String(localized: "Show/Hide Inspector"))
            }
        }
    }
    
    private func loadXML() async {
        do {
            let xml = try PlistSerializer.fileToXMLString(job.plistURL)
            xmlContent = xml
            diskXML = xml
        } catch {
            xmlContent = String(localized: "Failed to load XML: \(error.localizedDescription)")
        }
    }
    
    private func revertChanges() {
        if codeMode {
            // 重新加载原 XML
            Task { await loadXML() }
            // 同时重置表单草稿为原本状态
            viewModel.revert()
        } else {
            viewModel.revert()
        }
    }
    
    private func applyChanges() async {
        do {
            if codeMode {
                // 如果在 XML 模式下，首先尝试将最新的 XML 内容应用到 ViewModel 草稿
                try viewModel.applyXML(xmlContent)
            }
            // 保存并重载服务
            try await viewModel.save()
            
            // 保存成功后重新载入 XML 面板显示并刷新诊断
            await loadXML()
            diagnostics = DiagnosticsService.shared.analyze(job)
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
    
    private var runningStatusText: String {
        switch job.status {
        case .running(let pid):
            String(localized: "Running (PID: \(pid))")
        case .error(let code):
            String(localized: "Error (\(code))")
        default:
            String(localized: "Not Running", comment: "Status label")
        }
    }
}

// MARK: - Overview Tab

private extension DiagnosticEntry {
    var iconName: String {
        switch severity {
        case .error: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch severity {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
    
    var backgroundColor: Color {
        color.opacity(0.1)
    }
    
    var strokeColor: Color {
        color.opacity(0.3)
    }
}

private struct OverviewTabView: View {
    let job: LaunchdJob
    
    private var diagnostics: [DiagnosticEntry] {
        DiagnosticsService.shared.analyze(job)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 智能配置诊断报告
                if !diagnostics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(diagnostics) { diag in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: diag.iconName)
                                    .font(.title3)
                                    .foregroundStyle(diag.color)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(diag.message)
                                        .font(.headline)
                                    if let suggestion = diag.suggestion {
                                        Text(suggestion)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(diag.backgroundColor)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(diag.strokeColor, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.bottom, 8)
                }
                
                // 状态卡片
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(
                            String(localized: "Status", comment: "Overview label"),
                            value: job.status.displayText
                        )
                        LabeledContent(
                            String(localized: "Category", comment: "Overview label"),
                            value: job.category.displayName
                        )
                        LabeledContent(
                            String(localized: "Disabled", comment: "Overview label"),
                            value: job.disabled 
                                ? String(localized: "Yes", comment: "Boolean value") 
                                : String(localized: "No", comment: "Boolean value")
                        )
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label(
                        String(localized: "General", comment: "Overview section"),
                        systemImage: "info.circle"
                    )
                }
                
                // 程序信息
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        if let program = job.program {
                            LabeledContent(
                                String(localized: "Program", comment: "Overview label"),
                                value: program
                            )
                        }
                        if !job.programArguments.isEmpty {
                            LabeledContent(String(localized: "Arguments", comment: "Overview label")) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(job.programArguments, id: \.self) { arg in
                                        Text(arg)
                                            .font(.system(.body, design: .monospaced))
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label(
                        String(localized: "Program", comment: "Overview section"),
                        systemImage: "terminal"
                    )
                }
                
                // 调度信息
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(
                            String(localized: "Run at Load", comment: "Overview label"),
                            value: job.runAtLoad 
                                ? String(localized: "Yes", comment: "Boolean value") 
                                : String(localized: "No", comment: "Boolean value")
                        )
                        if let interval = job.startInterval {
                            LabeledContent(
                                String(localized: "Start Interval", comment: "Overview label"),
                                value: String(localized: "\(interval) seconds", comment: "Interval value")
                            )
                        }
                        if !job.startCalendarIntervals.isEmpty {
                            LabeledContent(String(localized: "Calendar Intervals", comment: "Overview label")) {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(job.startCalendarIntervals) { interval in
                                        Text(interval.displayDescription)
                                    }
                                }
                            }
                        }
                        if let keepAlive = job.keepAlive {
                            LabeledContent(
                                String(localized: "Keep Alive", comment: "Overview label"),
                                value: keepAlive.isEnabled 
                                    ? String(localized: "Yes", comment: "Boolean value") 
                                    : String(localized: "No", comment: "Boolean value")
                            )
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label(
                        String(localized: "Schedule", comment: "Overview section"),
                        systemImage: "clock"
                    )
                }
                
                // 文件路径
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent(
                            String(localized: "Plist Path", comment: "Overview label"),
                            value: job.plistURL.path
                        )
                        if let stdout = job.standardOutPath {
                            LabeledContent(
                                String(localized: "Standard Output", comment: "Overview label"),
                                value: stdout
                            )
                        }
                        if let stderr = job.standardErrorPath {
                            LabeledContent(
                                String(localized: "Standard Error", comment: "Overview label"),
                                value: stderr
                            )
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label(
                        String(localized: "Paths", comment: "Overview section"),
                        systemImage: "folder"
                    )
                }
            }
            .padding()
        }
    }
}

/// 顶部工具栏控制按钮子视图，确保依赖 Observation 的 job 属性更新能自动重绘视图
private struct ToolbarButtonsView: View {
    let job: LaunchdJob
    @Environment(JobListViewModel.self) private var listViewModel
    
    var body: some View {
        ControlGroup {
            Button {
                Task { await listViewModel.loadService(job) }
            } label: {
                Label(String(localized: "Load"), systemImage: "tray.and.arrow.down")
            }
            .disabled(job.status.isLoaded)
            .help(String(localized: "Load Service"))
            
            Button {
                Task { await listViewModel.unloadService(job) }
            } label: {
                Label(String(localized: "Unload"), systemImage: "tray.and.arrow.up")
            }
            .disabled(!job.status.isLoaded)
            .help(String(localized: "Unload Service"))
            
            Button {
                Task { await listViewModel.startService(job) }
            } label: {
                Label(String(localized: "Start"), systemImage: "play.fill")
            }
            .disabled(!job.status.isLoaded)
            .help(String(localized: "Start Service"))
            
            Button {
                Task { await listViewModel.stopService(job) }
            } label: {
                Label(String(localized: "Stop"), systemImage: "square.fill")
            }
            .disabled(!job.status.isRunning)
            .help(String(localized: "Stop Service"))
            
            Button {
                Task { await listViewModel.enableService(job) }
            } label: {
                Label(String(localized: "Enable"), systemImage: "checkmark.circle")
            }
            .disabled(!job.disabled)
            .help(String(localized: "Enable Service"))
            
            Button {
                Task { await listViewModel.disableService(job) }
            } label: {
                Label(String(localized: "Disable"), systemImage: "xmark.circle")
            }
            .disabled(job.disabled)
            .help(String(localized: "Disable Service"))
        }
        .controlGroupStyle(.navigation)
    }
}
