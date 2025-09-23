import SwiftUI
import Charts

// グラフ
struct SeverityTimeChart: View {
    let logs: [ColinLog]
    let baseDate: Date
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
                ContentUnavailableView("データなし", systemImage: "chart.bar.xaxis", description: Text("この日にログはありません"))
                    .frame(maxWidth: .infinity, minHeight: 140)
            } else {
                Chart(points) { pt in
                    // 棒グラフ (BarMark を使用)
                    BarMark(
                        x: .value("時刻", pt.time),
                        y: .value("症状", pt.severity)
                    )
                    .foregroundStyle(gradient(for: pt.severity))
                    .cornerRadius(4)
                    .annotation(position: .top, alignment: .center) {
                        // 小さな数値ラベル（バーが高い場合のみ）
                        if pt.severity >= 4 { Text("\(pt.severity)").font(.caption2).bold().foregroundStyle(.secondary) }
                    }
                }
                .chartXScale(domain: anchorStart...anchorEnd)
                .chartYScale(domain: 0...5) // 0 起点でバーの高さが直感的
                .chartYAxis { AxisMarks(values: [0,1,2,3,4,5]) }
                .chartXAxis {
                    let hours = stride(from: 0, through: 24, by: 6).map { Calendar.current.date(byAdding: .hour, value: $0, to: anchorStart)! }
                    AxisMarks(values: hours) { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                        AxisTick()
                        if let date = value.as(Date.self) { AxisValueLabel { Text(hourFormatter.string(from: date)) } }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    // ベース色 (severityごとに赤に近づく)
    private func baseColor(for severity: Int) -> Color {
        switch severity {
        case 1: return .blue
        case 2: return .teal
        case 3: return .yellow
        case 4: return .orange
        default: return .red
        }
    }
    // バー内グラデーション: 下からレベル到達色まで段階色を積み上げ (1:青 / 2:青→緑 / 3:青→緑→黄 / 4:青→緑→黄→オレンジ / 5:青→緑→黄→オレンジ→赤)
    private func gradient(for severity: Int) -> LinearGradient {
        let palette: [Color] = [.blue, .green, .yellow, .orange, .red]
        let capped = max(1, min(severity, palette.count))
        let slice = Array(palette.prefix(capped))
        // 単色の場合は二重にしてグラデーション表現を維持
        let colors: [Color] = slice.count == 1 ? [slice[0], slice[0]] : slice
        return LinearGradient(colors: colors, startPoint: .bottom, endPoint: .top)
    }
    private var hourFormatter: DateFormatter { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f }
}

// レベルバッジ
struct SeverityBadge: View {
    let severity: ColinLog.Severity
    static let fixedWidth: CGFloat = 72
    private var color: Color {
        switch severity {
        case .level1: return .blue
        case .level2: return Color(hue: 0.47, saturation: 0.65, brightness: 0.88)
        case .level3: return .yellow
        case .level4: return .orange
        case .level5: return .red
        }
    }
    var body: some View {
        VStack(spacing: 2) {
            Text("\(severity.rawValue)").font(.caption2).bold().foregroundColor(color == .yellow ? .black : .white)
            Text(severity.label).font(.caption2).lineLimit(1).minimumScaleFactor(0.7).foregroundColor(color == .yellow ? .black : .white)
        }
        .frame(width: Self.fixedWidth)
        .padding(.vertical, 6)
        .background(color.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// 発汗インライン
struct SweatLevelInline: View {
    let sweating: ColinLog.SweatingLevel
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "drop.circle").font(.system(size: 18, weight: .regular)).foregroundColor(.cyan)
            Text(sweating.label).font(.caption2).foregroundColor(.cyan)
        }
        .frame(width: SeverityBadge.fixedWidth)
    }
}

// ローセル
struct ColinLogRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let log: ColinLog
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(spacing: 4) {
                SeverityBadge(severity: log.severity)
                SweatLevelInline(sweating: log.sweating)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 2) {
                    Text(log.createdAt.colinMonthDay).font(.caption).bold().monospacedDigit()
                    Text(log.createdAt.colinTimeHHmm).font(.caption).bold().monospacedDigit()
                }
                HStack(spacing: 6) { triggerTag; responseTag }
                Text(log.detail ?? "詳細はありません").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
        }
        .frame(minHeight: 64)
    }
    private var triggerTag: some View { combinedTag(label: "原因", icon: log.trigger.iconSystemName, text: log.triggerDescription, color: triggerColor(log.trigger)) }
    private var responseTag: some View { combinedTag(label: "対処", icon: log.response.iconSystemName, text: log.responseDescription, color: responseColor(log.response)) }
    private func combinedTag(label: String, icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal,5).padding(.vertical,2)
                .background(color.opacity(0.9))
                .clipShape(Capsule())
                .foregroundStyle(colorScheme == .dark ? .black : .white)
            HStack(spacing:3){ Image(systemName: icon).font(.caption2.bold()); Text(text).font(.caption2).lineLimit(1) }
                .foregroundStyle(color)
        }
        .padding(.horizontal,8).padding(.vertical,4)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
    }
    private func triggerColor(_ t: ColinLog.Trigger) -> Color {
        switch t {
        case .stressEmotion: return .orange
        case .exercise: return .green
        case .bath: return .teal
        case .highTemp: return .red
        case .afterSweat: return .blue
        case .spicyHotIntake: return .pink
        case .dontKnow: return .gray
        case .other: return .gray
        }
    }
    private func responseColor(_ r: ColinLog.ResponseAction) -> Color {
        switch r {
        case .none: return .gray
        case .icePack: return .cyan
        case .shower: return .teal
        case .coolSpray: return .mint
        case .coolPlace: return .cyan
        case .antiItch: return .purple
        case .scratched: return .orange
        case .other: return .gray
        }
    }
}
