import SwiftUI

/// 新建服务向导 Sheet 视图
struct NewJobView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: JobDetailViewModel
    
    /// 创建成功后的回调闭包
    let onCreated: () -> Void
    
    init(defaultCategory: JobCategory = .userAgent, onCreated: @escaping () -> Void) {
        self._viewModel = State(wrappedValue: JobDetailViewModel(creatingInCategory: defaultCategory))
        self.onCreated = onCreated
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 复用表单编辑器，在新建时即可配置所有字段
                FormEditorView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                
                // 底部操作栏
                HStack(spacing: 12) {
                    if let firstError = viewModel.validationErrors.first {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text(firstError)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }
                    }
                    
                    Spacer()
                    
                    Button(String(localized: "Cancel", comment: "Button label")) {
                        dismiss()
                    }
                    
                    Button(String(localized: "Create", comment: "Button label")) {
                        createService()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle(String(localized: "New Service", comment: "Window title"))
        }
        .frame(minWidth: 650, minHeight: 500)
    }
    
    private func createService() {
        Task {
            do {
                try await viewModel.save()
                onCreated()
                dismiss()
            } catch {
                viewModel.validationErrors = [error.localizedDescription]
            }
        }
    }
}
