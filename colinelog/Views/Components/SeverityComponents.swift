import SwiftUI
import Charts

// グラフ
struct SeverityTimeChart: View {
    let logs: [ColinLog]
    let baseDate: Date
    private var anchorStart: Date { Calendar.current.startOfDay(for: baseDate) }
    private var anchorEnd: Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 1, to: anchorStart) ?? anchorStart.addingTimeInterval(24*60*60)
    }
    private struct PlotPoint: Identifiable { let id = UUID(); let time: Date; let severity: Int; let original: ColinLog }
    private var points: [PlotPoint] {
        let cal = Calendar.current
        return logs
            .filter { $0.kind == .symptom } // メモ除外
            .compactMap { log in
                let c = cal.dateComponents([.hour, .minute, .second], from: log.createdAt)
                guard let h = c.hour, let m = c.minute, let s = c.second else { return nil }
                let mapped = cal.date(bySettingHour: h, minute: m, second: s, of: anchorStart) ?? log.createdAt
                return PlotPoint(time: mapped, severity: log.severity.rawValue, original: log)
            }
            .sorted { $0.time < $1.time }
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
                .chartYAxis(content: { AxisMarks(values: [0,1,2,3,4,5]) })
                .chartXAxis(content: {
                    AxisMarks(values: xAxisTicks, content: { value in
                        AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
                        AxisTick()
                        if let date = value.as(Date.self) { AxisValueLabel { Text(hourFormatter.string(from: date)) } }
                    })
                 })
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
    // X軸の目盛（計算はビルダー外で行う）
    private var xAxisTicks: [Date] {
        let cal = Calendar.current
        var ticks: [Date] = []
        var current = anchorStart
        let step = 6 // hours
        while current < anchorEnd {
            ticks.append(current)
            guard let next = cal.date(byAdding: .hour, value: step, to: current) else { break }
            current = next
        }
        ticks.append(anchorEnd)
        return ticks
    }
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

// 発疹インライン
struct RashLevelInline: View {
    let rash: ColinLog.RashLevel
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: rash.iconSystemName)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(rash.color)
            Text(rash.label)
                .font(.caption2)
                .foregroundColor(rash.color)
        }
        .frame(width: SeverityBadge.fixedWidth)
        .accessibilityLabel("発疹: \(rash.label)")
    }
}

// ローセル
struct ColinLogRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let log: ColinLog
    var fullDetail: Bool = false
    var body: some View {
        if log.kind == .memo {
            HStack(alignment: .top, spacing: 8) {
                memoBadge
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(log.createdAt.colinMonthDay).font(.caption).bold().monospacedDigit()
                        Text(log.createdAt.colinTimeHHmm).font(.caption).bold().monospacedDigit()
                        Spacer(minLength: 0)
                    }
                    Text(log.detail ?? "(内容なし)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(fullDetail ? nil : 2)
                }
                Spacer()
            }
            .frame(minHeight: 52)
        } else {
            HStack(alignment: .center, spacing: 8) {
                VStack(spacing: 4) {
                    SeverityBadge(severity: log.severity)
                    SweatLevelInline(sweating: log.sweating)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 2) {
                        Text(log.createdAt.colinMonthDay).font(.caption).bold().monospacedDigit()
                        Text(log.createdAt.colinTimeHHmm).font(.caption).bold().monospacedDigit()
                        Spacer()
                        // rash が .noRash 以外なら表示
                        if log.rash != .noRash { rashText }
                    }
                    HStack(spacing: 6) { triggerTag; responseTag }
                    Text(log.detail ?? "詳細はありません")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(fullDetail ? nil : 1)
                }
                Spacer()
            }
            .frame(minHeight: 64)
        }
    }
    private var memoBadge: some View {
        VStack(spacing: 2) {
            Image(systemName: "note.text")
                .font(.caption2.bold())
                .foregroundColor(.white)
            Text("メモ")
                .font(.caption2)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: SeverityBadge.fixedWidth)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel("メモ")
    }
    private var triggerTag: some View { combinedTag(label: "原因", icon: log.trigger.iconSystemName, text: log.triggerDescription, color: log.trigger.color) }
    private var responseTag: some View { combinedTag(label: "対処", icon: log.response.iconSystemName, text: log.responseDescription, color: log.response.color) }
    private var rashText: some View {
        let color = log.rash.color
        return HStack(spacing: 6) {
            Image(systemName: log.rash.iconSystemName)
                .font(.caption2)
                .foregroundColor(color)
            Text(log.rashDescription)
                .font(.caption2)
                .foregroundColor(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
    private func combinedTag(label: String, icon: String, text: String, color: Color) -> some View {
        return HStack(spacing: 4) {
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
}
