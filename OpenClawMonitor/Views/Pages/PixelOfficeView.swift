import SwiftUI

struct PixelOfficeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 52))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.indigo)

            Text("Pixel Office")
                .font(.title2)
                .fontWeight(.bold)

            Text("像素办公室 · SpriteKit")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Phase 5 で実装")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.regularMaterial, in: Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}
