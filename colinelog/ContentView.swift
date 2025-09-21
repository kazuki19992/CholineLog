//
//  ContentView.swift
//  colinelog
//
//  Created by 櫛田一樹 on 2025/09/21.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    // 編集用: Bool 排除し item シートに一本化
    @State private var editingLog: ColinLog? = nil
    @Query(sort: [SortDescriptor(\ColinLog.createdAt, order: .reverse)]) private var logs: [ColinLog]

    var body: some View {
        ZStack { backgroundGradient
            NavigationStack { listContent }
                .background(Color.clear)
        }
    }

    private var backgroundGradient: some View {
        LinearGradient(colors: [.blue, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }

    private var listContent: some View {
        List {
            if logs.isEmpty { emptySection }
            ForEach(logs) { log in
                NavigationLink { detailView(log) } label: { ColinLogRow(log: log) }
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteLogs)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .background(Color.clear)
        .navigationTitle("コリンログ")
        .toolbar { toolbarItems }
        .sheet(isPresented: $showAddSheet) { AddColinLogView() }
        .sheet(item: $editingLog) { log in
            EditColinLogView(log: log)
        }
        // プリウォーム: 重いコントロール(DatePicker 等)を一度レイアウトさせ初回遅延を低減
        .background(EditPrewarmView().allowsHitTesting(false).accessibilityHidden(true).opacity(0.01))
    }

    private var emptySection: some View {
        Section { Text("まだコリンログがありません").foregroundStyle(.secondary).listRowBackground(Color.clear) }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
        ToolbarItem { Button(action: { showAddSheet = true }) { Label("コリンログを追加する", systemImage: "plus") } }
    }

    @ViewBuilder
    private func detailView(_ log: ColinLog) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("日時") {
                    HStack(spacing: 8) {
                        Text(log.createdAt.colinISODate)
                        Text(log.createdAt.colinTimeHHmm)
                        Spacer()
                    }
                    .font(.body.monospacedDigit())
                }
                GroupBox("強さ") { SeverityBadge(severity: log.severity, sweating: log.sweating) }
                VStack(spacing: 12) {
                    GroupBox("メインの発症原因") { Text(log.triggerDescription) }
                    GroupBox("対応") { Text(log.responseDescription) }
                }
                if let detail = log.detail { GroupBox("詳細") { Text(detail) } }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.clear)
        .navigationTitle("詳細")
        .toolbarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("編集") { editingLog = log } } }
    }

    private func deleteLogs(offsets: IndexSet) {
        withAnimation {
            for index in offsets { modelContext.delete(logs[index]) }
        }
    }
}

// 共通 強さバッジビュー (発汗を内部3行目に表示、発汗はシアンで表示)
private struct SeverityBadge: View {
    let severity: ColinLog.Severity
    let sweating: ColinLog.SweatingLevel
    static let fixedWidth: CGFloat = 72 // private を外し行側で幅共有
    var showSweatingInside: Bool = true
    private var color: Color {
        switch severity {
        case .level1: return .blue
        case .level2: return Color(hue: 0.47, saturation: 0.65, brightness: 0.88)
        case .level3: return .yellow
        case .level4: return .orange
        case .level5: return .red
        }
    }
    private var sweatingText: String { sweating.label }
    var body: some View {
        VStack(alignment: .center, spacing: 2) {
            Text("\(severity.rawValue)")
                .font(.caption2).bold()
                .foregroundColor(color == .yellow ? .black : .white)
            Text(severity.label)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundColor(color == .yellow ? .black : .white)
            if showSweatingInside { // 既存の内部表示は詳細画面用に温存
                HStack(spacing: 4) {
                    Image(systemName: "drop.circle")
                        .font(.caption2)
                    Text(sweatingText)
                        .font(.caption2)
                        .bold()
                }
                .foregroundColor(.cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
        }
        .frame(width: Self.fixedWidth)
        .padding(.vertical, 6)
        .background(color.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("強さ \(severity.rawValue) \(severity.label), 発汗: \(sweatingText)")
    }
}

// 症状レベル下に独立表示する発汗インライン表示
private struct SweatLevelInline: View {
    let sweating: ColinLog.SweatingLevel
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "drop.circle")
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.cyan)
            Text(sweating.label)
                .font(.caption2)
                .foregroundColor(.cyan)
        }
        .frame(width: SeverityBadge.fixedWidth, alignment: .center) // 中央揃え
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("発汗: \(sweating.label)")
    }
}

private struct ColinLogRow: View {
    let log: ColinLog
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                SeverityBadge(severity: log.severity, sweating: log.sweating, showSweatingInside: false)
                SweatLevelInline(sweating: log.sweating)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    Text(log.createdAt.colinMonthDay)
                        .font(.caption).bold().monospacedDigit()
                    Text(log.createdAt.colinTimeHHmm)
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    triggerTag
                    responseTag
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(log.detail ?? "詳細はありません")
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.tail)
            }
            .frame(minHeight: 32, alignment: .center)
            Spacer()
        }
        .frame(minHeight: 64, alignment: .center)
    }

    // MARK: - 個別色タグ
    private var triggerTag: some View {
        combinedTag(categoryLabel: "原因", accessibilityPrefix: "原因", icon: log.trigger.iconSystemName, text: log.triggerDescription, color: triggerColor(log.trigger))
    }
    private var responseTag: some View {
        combinedTag(categoryLabel: "対処", accessibilityPrefix: "対応", icon: log.response.iconSystemName, text: log.responseDescription, color: responseColor(log.response))
    }

    private func combinedTag(categoryLabel: String, accessibilityPrefix: String, icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) { // 6 -> 4
            Text(categoryLabel)
                .font(.system(size: 9, weight: .bold)) // 10 -> 9
                .padding(.horizontal, 5) // 6 -> 5
                .padding(.vertical, 2) // 3 -> 2
                .background(color.opacity(0.9))
                .clipShape(Capsule())
                .foregroundStyle(Color.white)
            HStack(spacing: 3) { // 4 -> 3
                Image(systemName: icon)
                    .font(.caption2.bold())
                Text(text)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(color)
        }
        .padding(.horizontal, 8) // 12 -> 8
        .padding(.vertical, 4)   // 6 -> 4
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().stroke(color.opacity(0.40), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(accessibilityPrefix): \(text)")
    }

    private func triggerColor(_ t: ColinLog.Trigger) -> Color {
        switch t {
        case .stressEmotion: return .orange
        case .exercise: return .green
        case .bath: return .teal
        case .highTemp: return .red
        case .afterSweat: return .blue
        case .spicyHotIntake: return .pink
        case .other: return .gray
        }
    }
    private func responseColor(_ r: ColinLog.ResponseAction) -> Color {
        switch r {
        case .none: return .gray
        case .icePack: return .cyan
        case .shower: return .teal
        case .coolSpray: return .mint
        case .antiItch: return .purple
        case .scratched: return .orange
        case .other: return .gray
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: ColinLog.self, inMemory: true)
}

// プリウォーム用隠しビュー
private struct EditPrewarmView: View {
    @State private var date: Date = Date()
    @State private var tmpSeverity: ColinLog.Severity = .level1
    @State private var tmpResponse: ColinLog.ResponseAction = .none
    @State private var tmpTrigger: ColinLog.Trigger = .stressEmotion
    @State private var tmpSweating: ColinLog.SweatingLevel = .none
    var body: some View {
        VStack(spacing: 0) {
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .frame(height: 0)
                .clipped()
            HStack(spacing: 4) {
                ForEach(ColinLog.Severity.allCases) { s in
                    Text("\(s.rawValue)").font(.caption2)
                        .padding(2)
                        .background(Color.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .onTapGesture { tmpSeverity = s }
                }
            }
            .frame(height: 0)
            .clipped()
            Menu("_resp") {
                ForEach(ColinLog.ResponseAction.allCases) { r in Button(r.label) { tmpResponse = r } }
            }
            Menu("_trig") {
                ForEach(ColinLog.Trigger.allCases) { t in Button(t.label) { tmpTrigger = t } }
            }
            Picker("_sweat", selection: $tmpSweating) {
                ForEach(ColinLog.SweatingLevel.allCases) { s in Text(s.label).tag(s) }
            }.pickerStyle(.segmented)
        }
    }
}
