import SwiftUI

/// Small summary card used in the top stats strip of AgentsView (§3.3.1).
struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.indigo)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .contentTransition(.numericText())
                .animation(.default, value: value)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
