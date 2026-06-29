import SwiftUI

/// 服务列表行视图
struct JobRowView: View {
    let job: LaunchdJob
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 状态指示灯
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(job.label)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                HStack(spacing: 6) {
                    Text(job.status.isRunning ? String(localized: "Running", comment: "Status label") : String(localized: "Not Running", comment: "Status label"))
                        .foregroundStyle(job.status.isRunning ? .green : .secondary)
                    
                    if let pid {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(String(localized: "PID", comment: "Process identifier label"))
                            .foregroundStyle(.secondary)
                        Text(pid, format: .number)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(job.status.isLoaded ? String(localized: "Loaded", comment: "Status label") : String(localized: "Not Loaded", comment: "Status label"))
                        .foregroundStyle(job.status.isLoaded ? .blue : .secondary)
                    
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(job.disabled ? String(localized: "Disabled", comment: "Status label") : String(localized: "Enabled", comment: "Status label"))
                        .foregroundStyle(job.disabled ? .orange : .green)
                }
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 7)
    }
    
    private var statusColor: Color {
        switch job.status {
        case .running: .green
        case .loaded, .notLoaded, .stopped, .unknown: .yellow
        case .error: .red
        }
    }
    
    private var pid: Int? {
        if case .running(let pid) = job.status {
            pid
        } else {
            nil
        }
    }
}
