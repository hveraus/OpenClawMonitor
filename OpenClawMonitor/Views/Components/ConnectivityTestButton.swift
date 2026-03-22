import SwiftUI

enum TestState { case idle, testing, success, failure }

struct ConnectivityTestButton: View {
    @Binding var state: TestState
    let action: () async -> Void

    var body: some View {
        Button {
            guard state == .idle else { return }
            Task { await action() }
        } label: {
            Group {
                switch state {
                case .idle:
                    Label("测试连通性", systemImage: "network")
                case .testing:
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("测试中…")
                    }
                case .success:
                    Label("成功", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .failure:
                    Label("失败", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(state == .testing)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3), value: state == .testing)
    }
}
