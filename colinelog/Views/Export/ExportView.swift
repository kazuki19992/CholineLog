import SwiftUI

struct ExportView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up").font(.system(size: 48))
                Text("書き出し (準備中)").foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("書き出し")
        }
    }
}