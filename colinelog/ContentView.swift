//
//  ContentView.swift
//  colinelog
//
//  Created by 櫛田一樹 on 2025/09/21.
//

import SwiftUI
import SwiftData
import Charts // 追加

// ルート: 単一概要ビュー (TabView 削除)
struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    @State private var editingLog: ColinLog? = nil
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date()) // 追加: 選択日
    @Query(sort: [SortDescriptor(\ColinLog.createdAt, order: .reverse)]) private var logs: [ColinLog]
    private let calendar = Calendar.current
    private var isToday: Bool { calendar.isDate(selectedDate, inSameDayAs: Date()) }
    private var dayLogs: [ColinLog] { logs.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) } }
    var body: some View {
        ZStack { backgroundGradient
            NavigationStack {
                GeometryReader { geo in
                    VStack(spacing: 0) {
                        dateNavigator
                            .padding(.horizontal)
                            .padding(.top, 8)
                        SeverityTimeChart(logs: dayLogs, baseDate: selectedDate)
                            .frame(height: max(180, geo.size.height * 0.40))
                            .padding(.horizontal)
                        Divider().opacity(0.3)
                        listContent
                    }
                    .contentShape(Rectangle())
                    .gesture(daySwipeGesture)
                    .animation(.easeInOut, value: selectedDate)
                }
                .navigationTitle("概要")
                .toolbarTitleDisplayMode(.inline)
                .toolbar { toolbarItems }
                .sheet(isPresented: $showAddSheet) { AddColinLogView() }
                .sheet(item: $editingLog) { log in EditColinLogView(log: log) }
            }
            .background(Color.clear)
        }
    }

    // 日付ナビゲーション
    private var dateNavigator: some View {
        HStack(spacing: 12) {
            Button(action: previousDay) { Image(systemName: "chevron.left") }
            Text(formattedSelectedDate)
                .font(.headline)
                .frame(maxWidth: .infinity)
                // .contentTransition(.numericText) // 対応OS差異で曖昧さ発生のため削除
            Button(action: nextDay) { Image(systemName: "chevron.right") }
                .disabled(isToday)
                .opacity(isToday ? 0.3 : 1)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
    }
    private var formattedSelectedDate: String {
        let df = DateFormatter(); df.locale = Locale(identifier: "ja_JP"); df.dateFormat = "yyyy/MM/dd (E)"; return df.string(from: selectedDate)
    }
    private func previousDay() { if let d = calendar.date(byAdding: .day, value: -1, to: selectedDate) { selectedDate = d } }
    private func nextDay() { guard !isToday else { return }; if let d = calendar.date(byAdding: .day, value: 1, to: selectedDate), d <= Date() { selectedDate = d } }
    private var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                if dx > 70 { previousDay() } else if dx < -70 { nextDay() }
            }
    }

    private var listContent: some View {
        List {
            if dayLogs.isEmpty { emptySection }
            ForEach(dayLogs) { log in
                NavigationLink { detailView(log) } label: { ColinLogRow(log: log) }
                    .listRowBackground(Color.clear)
            }
            .onDelete(perform: deleteDayLogs)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .background(Color.clear)
    }

    private var backgroundGradient: some View {
        LinearGradient(colors: [.blue, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
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

    private func deleteDayLogs(offsets: IndexSet) {
        withAnimation { for i in offsets { modelContext.delete(dayLogs[i]) } }
    }
    private func deleteLogs(offsets: IndexSet) { /* 後方互換: 未使用 */ }
}

// 時刻×症状レベル折れ線グラフ
private struct SeverityTimeChart: View {
    let logs: [ColinLog] // 選択日でフィルタ済み
    let baseDate: Date   // 0-24h の基準日
    private var anchorStart: Date { Calendar.current.startOfDay(for: baseDate) }
    private var anchorEnd: Date { Calendar.current.date(byAdding: .hour, value: 24, to: anchorStart)! }
    private struct PlotPoint: Identifiable { let id = UUID(); let time: Date; let severity: Int; let original: ColinLog }
    private var points: [PlotPoint] {
        let cal = Calendar.current
        return logs.compactMap { log in
            let c = cal.dateComponents([.hour, .minute, .second], from: log.createdAt)
            guard let h = c.hour, let m = c.minute, let s = c.second else { return nil }
            let mapped = cal.date(bySettingHour: h, minute: m, second: s, of: anchorStart) ?? log.createdAt
            return PlotPoint(time: mapped, severity: log.severity.rawValue, original: log)
        }.sorted { $0.time < $1.time }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Text("症状レベル推移").font(.headline); Spacer() }
            if points.isEmpty {
                ContentUnavailableView("データなし", systemImage: "chart.xyaxis.line", description: Text("この日にログはありません"))
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart(points) { pt in
                    LineMark(x: .value("時刻", pt.time), y: .value("症状", pt.severity))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("時刻", pt.time), y: .value("症状", pt.severity))
                        .foregroundStyle(color(for: pt.original.severity))
                        .symbolSize(40)
                }
                .chartXScale(domain: anchorStart...anchorEnd)
                .chartYScale(domain: 1...5)
                .chartYAxis { AxisMarks(values: [1,2,3,4,5]) }
                .chartXAxis {
                    let hours = stride(from: 0, through: 24, by: 6).map { Calendar.current.date(byAdding: .hour, value: $0, to: anchorStart)! }
                    AxisMarks(values: hours) { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.15))
                        AxisTick()
                        if let date = value.as(Date.self) {
                            AxisValueLabel {
                                Text(hourFormatter.string(from: date))
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    private func color(for severity: ColinLog.Severity) -> Color {
        switch severity { case .level1: return .blue; case .level2: return Color(hue: 0.47, saturation: 0.65, brightness: 0.88); case .level3: return .yellow; case .level4: return .orange; case .level5: return .red }
    }
    private var hourFormatter: DateFormatter { // 追加
        let df = DateFormatter(); df.dateFormat = "HH:mm"; return df
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
    @Environment(\.colorScheme) private var colorScheme // 追加
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
            let labelTextColor: Color = (colorScheme == .dark) ? .black : .white // 追加
            Text(categoryLabel)
                .font(.system(size: 9, weight: .bold)) // 10 -> 9
                .padding(.horizontal, 5) // 6 -> 5
                .padding(.vertical, 2) // 3 -> 2
                .background(color.opacity(0.9))
                .clipShape(Capsule())
                .foregroundStyle(labelTextColor) // 変更
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
    ContentView() // TabView 版
        .modelContainer(for: ColinLog.self, inMemory: true)
}
// 旧 Preview (OverviewView 単体) を差し替え
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

// 2) 新しい TabView ルート ContentView を定義
struct ContentView: View {
    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("概要", systemImage: "chart.line.uptrend.xyaxis") }
            LogsView()
                .tabItem { Label("コリンログ", systemImage: "list.bullet.rectangle") }
            ExportView()
                .tabItem { Label("書き出し", systemImage: "square.and.arrow.up") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
    }
}

// 3) コリンログ一覧タブ
private struct LogsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showAddSheet = false
    @State private var editingLog: ColinLog? = nil
    @Query(sort: [SortDescriptor(\ColinLog.createdAt, order: .reverse)]) private var logs: [ColinLog]
    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty { Section { Text("まだコリンログがありません").foregroundStyle(.secondary) } }
                ForEach(logs) { log in
                    NavigationLink { LogDetailView(log: log, editingLog: $editingLog) } label: { ColinLogRow(log: log) }
                }
                .onDelete(perform: deleteLogs)
            }
            .listStyle(.plain)
            .navigationTitle("コリンログ")
            .toolbar { toolbar }
            .sheet(isPresented: $showAddSheet) { AddColinLogView() }
            .sheet(item: $editingLog) { log in EditColinLogView(log: log) }
        }
    }
    private func deleteLogs(offsets: IndexSet) { withAnimation { offsets.forEach { modelContext.delete(logs[$0]) } } }
    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) { EditButton() }
        ToolbarItem { Button(action: { showAddSheet = true }) { Label("追加", systemImage: "plus") } }
    }
}

// 4) 書き出し / 設定 プレースホルダ
private struct ExportView: View { var body: some View { NavigationStack { Text("書き出し (準備中)").foregroundStyle(.secondary).navigationTitle("書き出し") } } }
private struct SettingsView: View { var body: some View { NavigationStack { Text("設定 (準備中)").foregroundStyle(.secondary).navigationTitle("設定") } } }

// 5) 詳細ビュー再利用 (LogsView 用)
private struct LogDetailView: View {
    let log: ColinLog
    @Binding var editingLog: ColinLog?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("日時") { HStack(spacing: 8) { Text(log.createdAt.colinISODate); Text(log.createdAt.colinTimeHHmm); Spacer() }.font(.body.monospacedDigit()) }
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
        .navigationTitle("詳細")
        .toolbarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("編集") { editingLog = log } } }
    }
}
