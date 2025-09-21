import SwiftUI

struct LogDetailView: View {
    let log: ColinLog
    @Binding var editingLog: ColinLog?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("日時") { HStack(spacing: 8) { Text(log.createdAt.colinISODate); Text(log.createdAt.colinTimeHHmm); Spacer() }.font(.body.monospacedDigit()) }
                GroupBox("強さ") {
                    SeverityBadge(severity: log.severity)
                    SweatLevelInline(sweating: log.sweating)
                }
                VStack(spacing: 12) {
                    GroupBox("メインの発症原因") { Text(log.triggerDescription) }
                    GroupBox("対応") { Text(log.responseDescription) }
                }
                if let detail = log.detail { GroupBox("詳細") { Text(detail) } }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("詳細")
        .toolbarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("編集") { editingLog = log } } }
    }
}
