import SwiftUI

/// 空状态提示视图
struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView {
            Label(
                String(localized: "No Service Selected", comment: "Empty state title"),
                systemImage: "square.dashed"
            )
        } description: {
            Text(
                "Select a service from the sidebar to view its details.",
                comment: "Empty state description"
            )
        }
    }
}
