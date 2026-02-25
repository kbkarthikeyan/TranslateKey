import SwiftUI

/// Horizontal popup showing diacritical variants above a key during long-press.
struct DiacriticsPopup: View {
    let variants: [String]
    let selectedIndex: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(variants.enumerated()), id: \.offset) { index, variant in
                Text(variant)
                    .font(.system(size: 22, weight: .light))
                    .frame(width: 36, height: 42)
                    .background(
                        index == selectedIndex
                            ? Color.blue : Color(.systemGray5),
                        in: .rect(cornerRadius: 6)
                    )
                    .foregroundStyle(index == selectedIndex ? .white : .primary)
            }
        }
        .padding(2)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
    }
}
