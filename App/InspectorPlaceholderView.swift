import SwiftUI

struct InspectorPlaceholderView: View {
    var body: some View {
        VStack {
            Text("Inspector")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
