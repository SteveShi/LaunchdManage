import SwiftUI

/// 分类头部视图
struct CategoryHeaderView: View {
    let category: JobCategory
    let count: Int
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.symbolName)
                .foregroundStyle(.secondary)
            Text("\(category.displayName) (\(count))")
        }
    }
}
