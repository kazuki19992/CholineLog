import SwiftUI

struct LogDetailView: View {
    let log: ColinLog
    @Binding var editingLog: ColinLog?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if log.kind == .memo {
                    GroupBox("日時") {
                        HStack(spacing: 8) { Text(log.createdAt.colinISODate); Text(log.createdAt.colinTimeHHmm); Spacer() }
                            .font(.body.monospacedDigit())
                    }
                    GroupBox("メモ") { Text(log.detail ?? "(内容なし)") }
                } else {
                    GroupBox("日時") { HStack(spacing: 8) { Text(log.createdAt.colinISODate); Text(log.createdAt.colinTimeHHmm); Spacer() }.font(.body.monospacedDigit()) }
                    GroupBox("強さ") {
                        VStack(alignment: .center, spacing: 8) {
                            SeverityBadge(severity: log.severity)
                            SweatLevelInline(sweating: log.sweating)
                            // 非オプショナル化後: .noRash の場合は表示しない（旧: nil の場合非表示）
                            if log.rash != .noRash { RashLevelInline(rash: log.rash) }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("強さ: レベル\(log.severity.rawValue) 発汗: \(log.sweating.label) 発疹: \(log.rash.label)")
                    }
                    VStack(spacing: 12) {
                        GroupBox("メインの発症原因") { Text(log.triggerDescription) }
                        GroupBox("対応") { Text(log.responseDescription) }
                    }
                    if let detail = log.detail { GroupBox("詳細") { Text(detail) } }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle("詳細")
        .toolbarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("編集") { editingLog = log } } }
    }
}
