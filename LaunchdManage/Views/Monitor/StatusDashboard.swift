import SwiftUI

struct StatusDashboard: View {
    let job: LaunchdJob
    @Environment(JobListViewModel.self) private var listViewModel
    
    @State private var pid: Int?
    @State private var status: JobStatus = .unknown
    @State private var usage: ProcessResourceUsage?
    @State private var timer: Timer?
    @State private var isRefreshing = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 第一板块：进程状态
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(statusText)
                                .font(.headline)
                        }
                        
                        Divider()
                        
                        VStack(spacing: 8) {
                            LabeledContent(String(localized: "PID")) {
                                if let pid = pid {
                                    Text(String(pid))
                                        .font(.system(.body, design: .monospaced))
                                } else {
                                    Text("-")
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            LabeledContent(String(localized: "Last Exit Code")) {
                                if let exitCode = job.lastExitCode {
                                    Text(String(exitCode))
                                        .foregroundColor(exitCode == 0 ? .gray : .red)
                                        .font(.system(.body, design: .monospaced))
                                } else {
                                    Text("-")
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .padding(8)
                } label: {
                    Label(String(localized: "Process Info"), systemImage: "info.circle")
                }
                
                // 第二板块：资源占用
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        if pid != nil, let usage = usage {
                            // CPU 占用
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(String(localized: "CPU"))
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.1f%%", usage.cpu))
                                        .font(.system(.subheadline, design: .monospaced))
                                }
                                ProgressView(value: min(usage.cpu, 100.0), total: 100.0)
                                    .tint(.green)
                            }
                            
                            // 内存占用
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(String(localized: "Memory"))
                                        .font(.subheadline)
                                    Spacer()
                                    Text(String(format: "%.1f%%", usage.memory))
                                        .font(.system(.subheadline, design: .monospaced))
                                }
                                ProgressView(value: min(usage.memory, 100.0), total: 100.0)
                                    .tint(.blue)
                            }
                            
                            Divider()
                            
                            LabeledContent(String(localized: "Uptime")) {
                                Text(usage.elapsed)
                                    .font(.system(.body, design: .monospaced))
                            }
                        } else {
                            VStack {
                                Text(String(localized: "Process is not running."))
                                    .foregroundColor(.gray)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 12)
                            }
                        }
                    }
                    .padding(8)
                } label: {
                    Label(String(localized: "Resource Usage"), systemImage: "chart.bar")
                }
                
                // 第三板块：快速控制
                GroupBox {
                    VStack(spacing: 8) {
                        // 启动/停止 (Kickstart/Kill)
                        HStack(spacing: 12) {
                            if pid != nil {
                                Button(role: .destructive) {
                                    Task { await stopService() }
                                } label: {
                                    Label(String(localized: "Stop"), systemImage: "stop.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button {
                                    Task { await startService() }
                                } label: {
                                    Label(String(localized: "Start"), systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(!status.isLoaded)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                        
                        // 加载/卸载 (Bootstrap/Bootout)
                        HStack(spacing: 12) {
                            if status.isLoaded {
                                Button(role: .destructive) {
                                    Task { await unloadService() }
                                } label: {
                                    Text(String(localized: "Unload"))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button {
                                    Task { await loadService() }
                                } label: {
                                    Text(String(localized: "Load"))
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        // 启用/禁用 (Enable/Disable)
                        HStack(spacing: 12) {
                            Button {
                                Task { await toggleDisabled() }
                            } label: {
                                Text(job.disabled ? String(localized: "Enable") : String(localized: "Disable"))
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(8)
                } label: {
                    Label(String(localized: "Control"), systemImage: "slider.horizontal.3")
                }
            }
            .padding()
        }
        .frame(minWidth: 260, idealWidth: 280, maxWidth: 320)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
        .onChange(of: job.id) { _, _ in
            // 切换服务时立即刷新
            Task { await refreshInfo() }
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .running: return .green
        case .loaded: return .blue
        case .error: return .red
        default: return .gray
        }
    }
    
    private var statusText: String {
        switch status {
        case .running: return String(localized: "Running")
        case .loaded: return String(localized: "Loaded")
        case .error: return String(localized: "Error")
        case .notLoaded: return String(localized: "Not Loaded")
        default: return String(localized: "Unknown")
        }
    }
    
    private func startTimer() {
        // 每 2 秒刷新一次状态和资源
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task {
                await refreshInfo()
            }
        }
        Task {
            await refreshInfo()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func refreshInfo() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            let newStatus = try await LaunchctlService.shared.getStatus(for: job)
            await MainActor.run {
                self.status = newStatus
                switch newStatus {
                case .running(let currentPID):
                    self.pid = currentPID
                default:
                    self.pid = nil
                    self.usage = nil
                }
            }
            
            if let activePID = self.pid {
                let activeUsage = await LaunchctlService.shared.getProcessResourceUsage(pid: activePID)
                await MainActor.run {
                    self.usage = activeUsage
                }
            }
        } catch {
            // 忽略读取错误
        }
    }
    
    // MARK: - 操作
    
    private func startService() async {
        do {
            try await LaunchctlService.shared.kickstartService(
                domain: job.category.domainTarget,
                label: job.label
            )
            await refreshInfo()
            await listViewModel.refreshStatus()
        } catch {
            // 忽略错误
        }
    }
    
    private func stopService() async {
        do {
            // 发送 SIGTERM 信号 (15) 停止服务
            try await LaunchctlService.shared.sendSignal(15, domain: job.category.domainTarget, label: job.label)
            await refreshInfo()
            await listViewModel.refreshStatus()
        } catch {
            // 忽略错误
        }
    }
    
    private func loadService() async {
        await listViewModel.loadService(job)
        await refreshInfo()
    }
    
    private func unloadService() async {
        await listViewModel.unloadService(job)
        await refreshInfo()
    }
    
    private func toggleDisabled() async {
        do {
            if job.disabled {
                try await LaunchctlService.shared.enableService(domain: job.category.domainTarget, label: job.label)
                job.disabled = false
            } else {
                try await LaunchctlService.shared.disableService(domain: job.category.domainTarget, label: job.label)
                job.disabled = true
            }
            await refreshInfo()
            await listViewModel.refreshStatus()
        } catch {
            // 忽略错误
        }
    }
}
