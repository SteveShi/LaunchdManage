import SwiftUI

/// 可视化 plist 表单编辑器
struct FormEditorView: View {
    @Bindable var viewModel: JobDetailViewModel
    @Environment(\.undoManager) private var undoManager
    
    var body: some View {
        Form {
            // MARK: - 基础配置
            Section(String(localized: "Identity & General", comment: "Form section")) {
                TextField(String(localized: "Label", comment: "Form label"), text: $viewModel.label)
                
                Picker(String(localized: "Category", comment: "Form label"), selection: undoableBinding(\.category)) {
                    ForEach(JobCategory.allCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                
                Toggle(String(localized: "Disabled", comment: "Form label"), isOn: undoableBinding(\.disabled))
            }
            
            // MARK: - 执行程序
            Section(String(localized: "Launch Program", comment: "Form section")) {
                HStack {
                    TextField(String(localized: "Program Path", comment: "Form label"), text: $viewModel.program)
                        .textFieldStyle(.roundedBorder)
                    Button(String(localized: "Choose...", comment: "Button label")) {
                        chooseFile { path in
                            viewModel.program = path
                        }
                    }
                }
                
                LabeledContent(String(localized: "Arguments (argv)", comment: "Form label")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(viewModel.programArguments.enumerated()), id: \.offset) { index, _ in
                            HStack {
                                TextField("argv[\(index)]", text: Binding(
                                    get: { viewModel.programArguments[index] },
                                    set: { viewModel.programArguments[index] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                
                                Button {
                                    viewModel.programArguments.remove(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Button {
                            viewModel.programArguments.append("")
                        } label: {
                            Label(String(localized: "Add Argument", comment: "Button label"), systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            
            // MARK: - 调度配置
            Section(String(localized: "Scheduling & Keep Alive", comment: "Form section")) {
                Toggle(String(localized: "Run at Load", comment: "Form label"), isOn: undoableBinding(\.runAtLoad))
                
                Toggle(String(localized: "Start Interval (Seconds)", comment: "Form label"), isOn: undoableBinding(\.startIntervalEnabled))
                if viewModel.startIntervalEnabled {
                    LabeledContent(String(localized: "Interval Value", comment: "Form label")) {
                        HStack(spacing: 8) {
                            TextField("", value: $viewModel.startInterval, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                                .multilineTextAlignment(.trailing)
                            
                            Stepper("", value: Binding(
                                get: { viewModel.startInterval ?? 10 },
                                set: { viewModel.startInterval = $0 }
                            ), in: 1...86400)
                            
                            Text("seconds (e.g. 3600 for 1 hour)", comment: "Detail hint label")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
                
                Toggle(String(localized: "Keep Alive", comment: "Form label"), isOn: undoableBinding(\.keepAliveEnabled))
                if viewModel.keepAliveEnabled {
                    LabeledContent(String(localized: "Keep Alive Type", comment: "Form label")) {
                        Picker("", selection: Binding(
                            get: {
                                if let config = viewModel.keepAlive {
                                    switch config {
                                    case .simple: return "simple"
                                    case .conditional: return "conditional"
                                    }
                                }
                                return "simple"
                            },
                            set: { type in
                                if type == "simple" {
                                    viewModel.keepAlive = .simple(true)
                                } else {
                                    viewModel.keepAlive = .conditional(KeepAliveConditions())
                                }
                            }
                        )) {
                            Text(String(localized: "Always", comment: "KeepAlive option")).tag("simple")
                            Text(String(localized: "Conditional", comment: "KeepAlive option")).tag("conditional")
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                    
                    if case .conditional(var conditions) = viewModel.keepAlive {
                        LabeledContent(String(localized: "Conditions", comment: "Form label")) {
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle(String(localized: "Only if successful exit", comment: "KeepAlive sub-option"), isOn: Binding(
                                    get: { conditions.successfulExit ?? false },
                                    set: { conditions.successfulExit = $0; viewModel.keepAlive = .conditional(conditions) }
                                ))
                                
                                Toggle(String(localized: "Only if crashed", comment: "KeepAlive sub-option"), isOn: Binding(
                                    get: { conditions.crashed ?? false },
                                    set: { conditions.crashed = $0; viewModel.keepAlive = .conditional(conditions) }
                                ))
                            }
                        }
                    }
                }
            }
            
            // MARK: - 环境与路径
            Section(String(localized: "Directory & Output Paths", comment: "Form section")) {
                HStack {
                    TextField(String(localized: "Working Directory", comment: "Form label"), text: $viewModel.workingDirectory)
                        .textFieldStyle(.roundedBorder)
                    Button(String(localized: "Choose...", comment: "Button label")) {
                        chooseDirectory { path in
                            viewModel.workingDirectory = path
                        }
                    }
                }
                
                TextField(String(localized: "Standard Out Path", comment: "Form label"), text: $viewModel.standardOutPath)
                    .textFieldStyle(.roundedBorder)
                TextField(String(localized: "Standard Error Path", comment: "Form label"), text: $viewModel.standardErrorPath)
                    .textFieldStyle(.roundedBorder)
            }
            
            // MARK: - 环境变量
            Section(String(localized: "Environment Variables", comment: "Form section")) {
                LabeledContent(String(localized: "Variables", comment: "Form label")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(viewModel.environmentVariables.keys.sorted(), id: \.self) { key in
                            HStack(spacing: 8) {
                                TextField(String(localized: "Key", comment: "Environment variable key"), text: Binding(
                                    get: { key },
                                    set: { newKey in
                                        guard !newKey.isEmpty && newKey != key else { return }
                                        let val = viewModel.environmentVariables[key] ?? ""
                                        viewModel.environmentVariables.removeValue(forKey: key)
                                        viewModel.environmentVariables[newKey] = val
                                    }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 150)
                                
                                Text("=", comment: "Equal sign separator")
                                    .foregroundStyle(.secondary)
                                
                                TextField(String(localized: "Value", comment: "Environment variable value"), text: Binding(
                                    get: { viewModel.environmentVariables[key] ?? "" },
                                    set: { viewModel.environmentVariables[key] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                
                                Button {
                                    viewModel.environmentVariables.removeValue(forKey: key)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Button {
                            let newKey = "ENV_VAR_\(viewModel.environmentVariables.count + 1)"
                            viewModel.environmentVariables[newKey] = ""
                        } label: {
                            Label(String(localized: "Add Variable", comment: "Button label"), systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            
            // MARK: - 进程配置
            Section(String(localized: "Process Parameters", comment: "Form section")) {
                Picker(String(localized: "Process Type", comment: "Form label"), selection: undoableBinding(\.processType)) {
                    Text(String(localized: "Default", comment: "Option label")).tag(ProcessType?.none)
                    ForEach(ProcessType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(ProcessType?.some(type))
                    }
                }
                
                Toggle(String(localized: "Throttle Interval", comment: "Form label"), isOn: undoableBinding(\.throttleIntervalEnabled))
                if viewModel.throttleIntervalEnabled {
                    LabeledContent(String(localized: "Delay Value", comment: "Form label")) {
                        HStack(spacing: 8) {
                            TextField("", value: Binding(
                                get: { viewModel.throttleInterval ?? 10 },
                                set: { viewModel.throttleInterval = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            
                            Stepper("", value: Binding(
                                get: { viewModel.throttleInterval ?? 10 },
                                set: { viewModel.throttleInterval = $0 }
                            ), in: 1...3600)
                            
                            Text("seconds", comment: "Seconds label")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
                
                Toggle(String(localized: "Nice (Priority adjustment)", comment: "Form label"), isOn: undoableBinding(\.niceEnabled))
                if viewModel.niceEnabled {
                    LabeledContent(String(localized: "Priority Value", comment: "Form label")) {
                        HStack(spacing: 8) {
                            TextField("", value: Binding(
                                get: { viewModel.nice ?? 0 },
                                set: { viewModel.nice = $0 }
                            ), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                            
                            Stepper("", value: Binding(
                                get: { viewModel.nice ?? 0 },
                                set: { viewModel.nice = $0 }
                            ), in: -20...20)
                            
                            Text("(Range: -20 to 20, lower is higher priority)", comment: "Detail hint label")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
    
    // MARK: - 辅助方法
    private func chooseFile(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
    }
    
    private func chooseDirectory(completion: @escaping (String) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            completion(url.path)
        }
    }
    
    private func undoableBinding<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<JobDetailViewModel, T>) -> Binding<T> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { newValue in
                let oldValue = viewModel[keyPath: keyPath]
                if oldValue != newValue {
                    undoManager?.registerUndo(withTarget: viewModel) { target in
                        target[keyPath: keyPath] = oldValue
                    }
                    viewModel[keyPath: keyPath] = newValue
                }
            }
        )
    }
}
