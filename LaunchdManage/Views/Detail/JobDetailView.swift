import SwiftUI

/// 服务详情主视图
struct JobDetailView: View {
    let job: LaunchdJob
    
    @State private var viewModel: JobDetailViewModel
    @State private var logViewModel: LogViewModel
    @State private var selectedTab: DetailTab = .overview
    @State private var xmlContent: String = ""
    @State private var xmlBeforeEditing: String = ""
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showInspector = false
    
    init(job: LaunchdJob) {
        self.job = job
        self._viewModel = State(wrappedValue: JobDetailViewModel(job: job))
        self._logViewModel = State(wrappedValue: LogViewModel(job: job))
    }
    
    enum DetailTab: String, CaseIterable {
        case overview
        case configuration
        case xml
        case logs
        
        var label: String {
            switch self {
            case .overview: String(localized: "Overview", comment: "Detail tab")
            case .configuration: String(localized: "Configuration", comment: "Detail tab")
            case .xml: String(localized: "XML", comment: "Detail tab")
            case .logs: String(localized: "Terminal", comment: "Detail tab")
            }
        }
        
        var icon: String {
            switch self {
            case .overview: "info.circle"
            case .configuration: "list.bullet.rectangle"
            case .xml: "chevron.left.forwardslash.chevron.right"
            case .logs: "terminal"
            }
        }
    }
    
    /// 检查当前视图是否处于脏状态（有修改未保存）
    private var hasChanges: Bool {
        if selectedTab == .xml {
            // 如果在 XML 标签页下，比较当前的 xmlContent 和原 job 文件内容
            if let originalXML = try? PlistSerializer.fileToXMLString(job.plistURL) {
                return xmlContent != originalXML
            }
            return true
        } else {
            return viewModel.isDirty
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab 选择器
            Picker(selection: $selectedTab) {
                ForEach(DetailTab.allCases, id: \.self) { tab in
                    Label(tab.label, systemImage: tab.icon)
                        .tag(tab)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 400) // 限制最大宽度，防止大屏拉长变形
            .padding(.horizontal)
            .padding(.vertical, 10)
            .onChange(of: selectedTab) { oldValue, newValue in
                // 在切换 Tab 时进行双模同步
                if newValue == .xml {
                    // 进入 XML 面板时
                    if viewModel.isDirty {
                        // 如果表单被修改过，从当前表单草稿同步生成最新 XML
                        if let draftXML = try? viewModel.generateDraftXML() {
                            xmlContent = draftXML
                        }
                    } else {
                        // 如果表单没有修改过，确保 xmlContent 保持为原文件内容
                        if let originalXML = try? PlistSerializer.fileToXMLString(job.plistURL) {
                            xmlContent = originalXML
                        }
                    }
                    // 记录进入 XML 时的初始内容，用来识别用户是否在此期间修改过 XML
                    xmlBeforeEditing = xmlContent
                } else if oldValue == .xml {
                    // 从 XML 面板切出时
                    // 只有在用户真的修改过 XML 的情况下，才尝试解析并更新表单
                    if xmlContent != xmlBeforeEditing {
                        do {
                            try viewModel.applyXML(xmlContent)
                        } catch {
                            errorMessage = String(localized: "Failed to sync XML back to form: \(error.localizedDescription)")
                            showErrorAlert = true
                            // 强制切回 XML tab 让用户修正
                            selectedTab = .xml
                        }
                    }
                }
                
                // 停止日志流（如果切出 logs tab）
                if oldValue == .logs {
                    logViewModel.stopStreaming()
                }
            }
            
            Divider()
            
            // Tab 内容
            ZStack {
                switch selectedTab {
                case .overview:
                    OverviewTabView(job: job)
                case .configuration:
                    FormEditorView(viewModel: viewModel)
                case .xml:
                    XMLPreviewView(xmlContent: $xmlContent)
                case .logs:
                    LogViewerView(viewModel: logViewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // 底部操作区 (悬浮毛玻璃药丸面板)
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
        .navigationTitle(job.label)
        .alert(
            String(localized: "Error", comment: "Alert title"),
            isPresented: $showErrorAlert,
            actions: { Button(String(localized: "OK", comment: "Button label"), role: .cancel) {} },
            message: { Text(errorMessage ?? "") }
        )
        .task(id: job.id) {
            await loadXML()
        }
        .inspector(isPresented: $showInspector) {
            StatusDashboard(job: job)
        }
        .toolbar {
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
            xmlContent = try PlistSerializer.fileToXMLString(job.plistURL)
        } catch {
            xmlContent = String(localized: "Failed to load XML: \(error.localizedDescription)")
        }
    }
    
    private func revertChanges() {
        if selectedTab == .xml {
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
            if selectedTab == .xml {
                // 如果在 XML 模式下，首先尝试将最新的 XML 内容应用到 ViewModel 草稿
                try viewModel.applyXML(xmlContent)
            }
            // 保存并重载服务
            try await viewModel.save()
            
            // 保存成功后重新载入 XML 面板显示
            await loadXML()
        } catch {
            errorMessage = error.localizedDescription
            showErrorAlert = true
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
