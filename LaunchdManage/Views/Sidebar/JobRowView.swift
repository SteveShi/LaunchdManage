import SwiftUI

/// 服务列表行视图
struct JobRowView: View {
    let job: LaunchdJob
    
    var body: some View {
        HStack(spacing: 8) {
            // 状态指示灯
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(job.label)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                if let program = job.program ?? job.programArguments.first {
                    Text(program)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            
            Spacer()
            
            if job.disabled {
                Text("Disabled", comment: "Service disabled badge")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 2)
    }
    
    private var statusColor: Color {
        switch job.status {
        case .running: .green
        case .loaded: .yellow
        case .error: .red
        case .stopped, .notLoaded, .unknown: .gray
        }
    }
}
