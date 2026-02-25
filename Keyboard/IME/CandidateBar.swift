import SwiftUI

/// Horizontal scrollable bar showing IME candidates. Used by Chinese and Japanese IMEs.
struct CandidateBar: View {
    let candidates: [String]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(candidates.enumerated()), id: \.offset) { index, candidate in
                    if index > 0 {
                        Divider()
                            .frame(height: 20)
                            .opacity(0.4)
                    }
                    Button {
                        onSelect(index)
                    } label: {
                        Text(candidate)
                            .font(.system(size: 17))
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .contentShape(Rectangle())
                    }
                    .foregroundStyle(index == 0 ? .blue : .primary)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
