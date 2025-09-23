import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ColinLog.createdAt, order: .forward)]) private var logs: [ColinLog]

    // 共有 / 書き出し
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    // 選択ワークフロー
    private enum ExportFormat { case text, markdown, json, pdf }
    private enum OutputMode: String, CaseIterable, Identifiable { case specific, filtered; var id: String { rawValue }; var label: String { self == .specific ? "特定のログ" : "期間と種類" } }
    private enum PeriodMode: String, CaseIterable, Identifiable { case all, range; var id: String { rawValue }; var label: String { self == .all ? "すべて" : "期間指定" } }

    @State private var outputMode: OutputMode = .specific
    @State private var periodMode: PeriodMode = .all
    @State private var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var includeSymptom = true
    @State private var includeMemo = true
    @State private var selectedLogIDs: Set<ColinLog.ID> = []

    // フォーマットシート
    @State private var showingFormat = false
    @State private var chosenFormat: ExportFormat? = nil

    // インライン計算ターゲット
    private var exportTarget: [ColinLog] { previewSelection() }
    private var canExport: Bool { !exportTarget.isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    selectionInline
                    selectionSummary
                    // 下部ボタン削除 (ヘッダーの「次へ」で遷移)
                }
                .padding(.top, 32)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("書き出し")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("次へ") { showingFormat = true }.disabled(!canExport) } }
            .sheet(isPresented: $showShare) { ActivityView(items: shareItems) }
            .sheet(isPresented: $showingFormat) { formatSheet }
            .onAppear { setDefaultSelectionIfNeeded() }
            .onChange(of: logs) { _, _ in setDefaultSelectionIfNeeded() }
            .onChange(of: outputMode) { _, new in if new == .specific { setDefaultSelectionIfNeeded(forceAll: selectedLogIDs.isEmpty) } }
        }
        .tint(.cyan)
    }

    // MARK: - インライン選択 UI
    private var selectionInline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("エクスポート対象を選択")
                .font(.headline)

            // モード切替
            Picker("", selection: $outputMode) {
                ForEach(OutputMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)

            Group {
                switch outputMode {
                case .specific:
                    specificInlineList
                case .filtered:
                    filteredInlineControls
                }
            }
        }
    }

    private var specificInlineList: some View {
        VStack(alignment: .leading, spacing: 12) {
            if logs.isEmpty {
                Text("ログがありません").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    let allSelected = !logs.isEmpty && selectedLogIDs.count == logs.count
                    Button(allSelected ? "すべて解除" : "すべて選択") { toggleSelectAll() }
                        .font(.caption)
                    Spacer()
                    Text("選択: \(selectedLogIDs.count)件").font(.caption).foregroundStyle(.secondary)
                }
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(logs) { log in
                        Button(action: { toggleSelection(log) }) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: selectedLogIDs.contains(log.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedLogIDs.contains(log.id) ? .cyan : .secondary)
                                    .padding(.top, 6)
                                ColinLogRow(log: log)
                                    .contentShape(Rectangle())
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if selectedLogIDs.isEmpty { Text("少なくとも1件選択してください").font(.caption2).foregroundStyle(.red) }
            }
        }
    }

    private var filteredInlineControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 期間
            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $periodMode) {
                    ForEach(PeriodMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if periodMode == .range {
                    DatePicker("開始", selection: $startDate, displayedComponents: .date)
                    DatePicker("終了", selection: $endDate, displayedComponents: .date)
                    if startDate > endDate { Text("開始日は終了日以前にしてください").font(.caption2).foregroundStyle(.red) }
                }
            }
            // 種類
            VStack(alignment: .leading, spacing: 8) {
                Toggle("症状ログ", isOn: $includeSymptom)
                Toggle("メモ", isOn: $includeMemo)
                if !includeSymptom && !includeMemo { Text("少なくとも1つ選択してください").font(.caption2).foregroundStyle(.red) }
            }
            // プレビュー
            VStack(alignment: .leading, spacing: 4) {
                Text("プレビュー (\(exportTarget.count)件)").font(.subheadline.bold())
                if exportTarget.isEmpty { Text("条件に合うログがありません").font(.caption).foregroundStyle(.secondary) }
                else {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(exportTarget.prefix(20)) { log in
                            ColinLogRow(log: log)
                                .padding(.vertical, 4)
                        }
                    }
                    if exportTarget.count > 20 { Text("… 他 \(exportTarget.count - 20) 件").font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
    }

    // MARK: - サマリー
    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("現在の対象")
                .font(.headline)
            if exportTarget.isEmpty {
                Text(outputMode == .specific ? "ログを選択してください" : "条件を調整してください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("件数: \(exportTarget.count)").font(.subheadline.bold())
                if outputMode == .filtered {
                    let periodText: String = {
                        if periodMode == .all { return "期間: すべて" }
                        return "期間: " + ymd(startDate) + " ~ " + ymd(endDate)
                    }()
                    Text(periodText).font(.caption).foregroundStyle(.secondary)
                    let kinds = [includeSymptom ? "症状ログ" : nil, includeMemo ? "メモ" : nil].compactMap { $0 }.joined(separator: ", ")
                    Text("種類: \(kinds)").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - フォーマットシート
    private var formatSheet: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Text("形式を選択").font(.headline).padding(.top, 8)
                Text("対象: \(exportTarget.count) 件").font(.caption).foregroundStyle(.secondary)
                VStack(spacing: 14) {
                    ExportButton(icon: "doc.plaintext", title: "テキスト", subtitle: "通常のテキスト形式で出力します", disabled: false) { chooseAndExport(.text) }
                    ExportButton(icon: "text.alignleft", title: "Markdown", subtitle: "ChatGPTへの共有やドキュメント作成に便利です", disabled: false) { chooseAndExport(.markdown) }
                    ExportButton(icon: "curlybraces", title: "JSON", subtitle: "データのバックアップに最適です", disabled: false) { chooseAndExport(.json) }
                    ExportButton(icon: "doc.richtext", title: "PDF", subtitle: "印刷してお医者さんに見せることができます", disabled: false) { chooseAndExport(.pdf) }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .navigationTitle("書き出し形式")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { showingFormat = false } } }
        }
        .tint(.cyan)
    }

    // MARK: - Selection Logic
    private func previewSelection() -> [ColinLog] {
        switch outputMode {
        case .specific:
            return logs.filter { selectedLogIDs.contains($0.id) }
        case .filtered:
            var base = logs
            if periodMode == .range {
                let startDay = Calendar.current.startOfDay(for: startDate)
                let endDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate
                base = base.filter { $0.createdAt >= startDay && $0.createdAt <= endDay }
            }
            return base.filter { (includeSymptom && $0.kind == .symptom) || (includeMemo && $0.kind == .memo) }
        }
    }

    private func toggleSelection(_ log: ColinLog) {
        if selectedLogIDs.contains(log.id) { selectedLogIDs.remove(log.id) } else { selectedLogIDs.insert(log.id) }
    }
    private func toggleSelectAll() {
        if selectedLogIDs.count == logs.count { selectedLogIDs.removeAll() } else { selectedLogIDs = Set(logs.map { $0.id }) }
    }

    // MARK: - Export Execution
    private func chooseAndExport(_ format: ExportFormat) { chosenFormat = format; runExport() }
    private func runExport() {
        guard let format = chosenFormat, !exportTarget.isEmpty else { return }
        switch format {
        case .text: exportPlainText(exportTarget)
        case .markdown: exportMarkdown(exportTarget)
        case .json: exportJSON(exportTarget)
        case .pdf: exportPDF(exportTarget)
        }
        chosenFormat = nil
        showingFormat = false
    }

    // MARK: - Export Generators
    private func exportPlainText(_ target: [ColinLog]) { let text = target.map { formattedLine(for: $0, markdown: false) }.joined(separator: "\n"); share(text: text, fileName: exportFileName(ext: "txt")) }
    private func exportMarkdown(_ target: [ColinLog]) { var md = "# コリンログエクスポート\n\n件数: \(target.count)\n\n"; target.forEach { md += "- " + formattedLine(for: $0, markdown: true) + "\n" }; share(text: md, fileName: exportFileName(ext: "md")) }
    private func exportJSON(_ target: [ColinLog]) { struct J: Codable { let createdAt: String; let severity: Int; let response: String; let trigger: String; let sweating: String; let detail: String?; let kind: String }; let iso = ISO8601DateFormatter(); let arr = target.map { J(createdAt: iso.string(from: $0.createdAt), severity: $0.severity.rawValue, response: $0.response.rawValue, trigger: $0.trigger.rawValue, sweating: $0.sweating.rawValue, detail: $0.detail, kind: $0.kind.rawValue) }; do { let data = try JSONEncoder().encode(arr); share(data: data, fileName: exportFileName(ext: "json"), uti: "public.json") } catch { } }
    private func exportPDF(_ target: [ColinLog]) {
#if canImport(UIKit)
        // A4 縦 (72dpi 換算)
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2
        let headerBottomSpace: CGFloat = 24
        let footerHeight: CGFloat = 40
        let dayHeadingFont = UIFont.boldSystemFont(ofSize: 18)
        let graphHeight: CGFloat = 140
        let columnGap: CGFloat = 16
        let columnWidth = (contentWidth - columnGap) / 2
        let rowSpacing: CGFloat = 14

        // ---- ログカードメトリクス ----
        let cardHPad: CGFloat = 12
        let cardVPad: CGFloat = 10
        let badgeWidth: CGFloat = 46
        let badgeCorner: CGFloat = 8
        let cardCorner: CGFloat = 14
        let lineGap: CGFloat = 4

        // フォント
        let timeFont = UIFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        let tagFont = UIFont.systemFont(ofSize: 9)
        let detailFont = UIFont.systemFont(ofSize: 11)
        let sevBigFont = UIFont.boldSystemFont(ofSize: 18)
        let sevSmallFont = UIFont.systemFont(ofSize: 9)

        func sevColor(_ v: Int) -> UIColor {
            switch v { case 5: return .systemRed; case 4: return .systemOrange; case 3: return .systemYellow; case 2: return .systemGreen; default: return .systemBlue }
        }

        // 高さ計測
        func measureCard(_ log: ColinLog, width: CGFloat) -> CGFloat {
            let textWidth = width - cardHPad*2 - badgeWidth - 8
            var h: CGFloat = cardVPad
            h += timeFont.lineHeight
            h += lineGap
            let tagLine = log.triggerDescription + "  " + log.responseDescription + "  発汗:" + log.sweating.label + (log.kind == .memo ? "  (メモ)" : "")
            let tagRect = (tagLine as NSString).boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin,.usesFontLeading], attributes: [.font: tagFont], context: nil)
            h += ceil(tagRect.height)
            if let d = log.detail, !d.isEmpty {
                h += lineGap
                let dRect = (d as NSString).boundingRect(with: CGSize(width: textWidth, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin,.usesFontLeading], attributes: [.font: detailFont], context: nil)
                h += ceil(dRect.height)
            }
            h += cardVPad
            return ceil(h)
        }

        func drawCard(_ log: ColinLog, at origin: CGPoint, width: CGFloat) -> CGFloat {
            let h = measureCard(log, width: width)
            let rect = CGRect(x: origin.x, y: origin.y, width: width, height: h)
            // 背景
            let path = UIBezierPath(roundedRect: rect, cornerRadius: cardCorner)
            UIColor.white.setFill(); path.fill()
            UIColor.black.withAlphaComponent(0.08).setStroke(); path.stroke()
            // バッジ
            let bRect = CGRect(x: rect.minX + cardHPad, y: rect.minY + cardVPad, width: badgeWidth - 14, height: 44)
            let bPath = UIBezierPath(roundedRect: bRect, cornerRadius: badgeCorner)
            let sc = sevColor(log.severity.rawValue)
            sc.withAlphaComponent(0.18).setFill(); bPath.fill()
            ("Lv" as NSString).draw(at: CGPoint(x: bRect.minX + 6, y: bRect.minY + 4), withAttributes: [.font: sevSmallFont, .foregroundColor: sc])
            ("\(log.severity.rawValue)" as NSString).draw(at: CGPoint(x: bRect.minX + 4, y: bRect.minY + 18), withAttributes: [.font: sevBigFont, .foregroundColor: sc])
            // テキスト領域
            var tx = rect.minX + cardHPad + badgeWidth
            var ty = rect.minY + cardVPad
            // 時刻
            let timeStr: String = { let f = DateFormatter(); f.dateFormat = "MM/dd HH:mm"; return f.string(from: log.createdAt) }()
            (timeStr as NSString).draw(at: CGPoint(x: tx, y: ty), withAttributes: [.font: timeFont, .foregroundColor: UIColor.label])
            ty += timeFont.lineHeight + lineGap
            // タグ
            let tagLine = log.triggerDescription + "  " + log.responseDescription + "  発汗:" + log.sweating.label + (log.kind == .memo ? "  (メモ)" : "")
            let tagAttr: [NSAttributedString.Key: Any] = [.font: tagFont, .foregroundColor: UIColor.darkGray]
            let tagRect = (tagLine as NSString).boundingRect(with: CGSize(width: rect.maxX - cardHPad - tx, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin,.usesFontLeading], attributes: tagAttr, context: nil)
            (tagLine as NSString).draw(in: CGRect(x: tx, y: ty, width: tagRect.width, height: ceil(tagRect.height)), withAttributes: tagAttr)
            ty += ceil(tagRect.height)
            if let d = log.detail, !d.isEmpty {
                ty += lineGap
                let dAttr: [NSAttributedString.Key: Any] = [.font: detailFont, .foregroundColor: UIColor.darkGray]
                let dRect = (d as NSString).boundingRect(with: CGSize(width: rect.maxX - cardHPad - tx, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin,.usesFontLeading], attributes: dAttr, context: nil)
                (d as NSString).draw(in: CGRect(x: tx, y: ty, width: dRect.width, height: ceil(dRect.height)), withAttributes: dAttr)
            }
            return h
        }

        // グラフ色
        let graphBorder = UIColor(white: 0.85, alpha: 1)
        let gridColor = UIColor(white: 0.9, alpha: 1)

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: target.sorted { $0.createdAt < $1.createdAt }) { calendar.startOfDay(for: $0.createdAt) }
        let orderedDays = grouped.keys.sorted()
        let todayStr = ymd(Date())

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let data = renderer.pdfData { ctx in
            var page = 0
            var y: CGFloat = 0

            func header() {
                page += 1
                ctx.beginPage()
                y = margin
                if let icon = appIconImage(size: 48), let cg = icon.cgImage { UIGraphicsGetCurrentContext()?.draw(cg, in: CGRect(x: margin, y: y, width: 48, height: 48)) }
                let titleX = margin + 56
                let title = "コリン性蕁麻疹 症状レポート (生成日: \(todayStr))"
                (title as NSString).draw(at: CGPoint(x: titleX, y: y + 4), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 18)])
                ("ユーザー名" as NSString).draw(at: CGPoint(x: titleX, y: y + 30), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.darkGray])
                y += 56
                let g = UIGraphicsGetCurrentContext()!
                g.setStrokeColor(UIColor.black.cgColor)
                g.setLineWidth(1)
                g.move(to: CGPoint(x: margin, y: y))
                g.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                g.strokePath()
                y += headerBottomSpace
            }
            func footer() {
                let g = UIGraphicsGetCurrentContext()!
                g.setStrokeColor(UIColor.black.cgColor)
                g.setLineWidth(1)
                g.move(to: CGPoint(x: margin, y: pageHeight - footerHeight))
                g.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - footerHeight))
                g.strokePath()
                ("Generated By コリンログ" as NSString).draw(at: CGPoint(x: margin, y: pageHeight - footerHeight + 14), withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])
                let right = "p.\(page)" as NSString
                let rSize = right.size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
                right.draw(at: CGPoint(x: pageWidth - margin - rSize.width, y: pageHeight - footerHeight + 14), withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])
            }
            func ensureSpace(_ needed: CGFloat) { if y + needed + footerHeight + 10 > pageHeight { footer(); header() } }

            func drawGraph(_ logs: [ColinLog], originY: inout CGFloat) {
                let rect = CGRect(x: margin, y: originY, width: contentWidth, height: graphHeight)
                let rPath = UIBezierPath(roundedRect: rect, cornerRadius: 14)
                UIColor(white: 0.97, alpha: 1).setFill(); rPath.fill()
                graphBorder.setStroke(); rPath.stroke()
                let g = UIGraphicsGetCurrentContext()!
                g.setStrokeColor(gridColor.cgColor); g.setLineWidth(0.8)
                for i in 0...5 {
                    let ly = rect.minY + CGFloat(i) * (rect.height - 20) / 5 + 10
                    g.move(to: CGPoint(x: rect.minX + 50, y: ly))
                    g.addLine(to: CGPoint(x: rect.maxX - 10, y: ly))
                }
                g.strokePath()
                for i in 1...5 {
                    let label = "\(i)" as NSString
                    let sz = label.size(withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
                    let ly = rect.maxY - 10 - CGFloat(i) * (rect.height - 20) / 5 - sz.height/2
                    label.draw(at: CGPoint(x: rect.minX + 32 - sz.width/2, y: ly), withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])
                }
                let times = [0,6,12,18,24]
                for t in times {
                    let s = String(format: "%02d:00", t) as NSString
                    let attr: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 9), .foregroundColor: UIColor.darkGray]
                    let x = rect.minX + 50 + CGFloat(t)/24.0 * (rect.width - 60)
                    let w = s.size(withAttributes: attr).width
                    s.draw(at: CGPoint(x: x - w/2, y: rect.maxY - 14), withAttributes: attr)
                }
                for log in logs {
                    let seconds = calendar.component(.hour, from: log.createdAt)*3600 + calendar.component(.minute, from: log.createdAt)*60 + calendar.component(.second, from: log.createdAt)
                    let ratio = CGFloat(seconds) / 86400.0
                    let barX = rect.minX + 50 + ratio * (rect.width - 60)
                    let barWidth: CGFloat = 6
                    let barMaxHeight = rect.height - 30
                    let barHeight = barMaxHeight * CGFloat(log.severity.rawValue) / 5.0
                    let barRect = CGRect(x: barX - barWidth/2, y: rect.maxY - 20 - barHeight, width: barWidth, height: barHeight)
                    sevColor(log.severity.rawValue).setFill(); UIBezierPath(roundedRect: barRect, cornerRadius: 2).fill()
                }
                ("症状レベル推移" as NSString).draw(at: CGPoint(x: rect.minX + 12, y: rect.minY + 8), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.darkGray])
                (todayStr as NSString).draw(at: CGPoint(x: rect.maxX - 60, y: rect.minY + 8), withAttributes: [.font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray])
                originY += graphHeight
            }

            header()
            for day in orderedDays {
                guard let dayLogs = grouped[day] else { continue }
                // 高さ見積り
                let est = 32 + graphHeight + CGFloat((dayLogs.count + 1)/2) * 130
                ensureSpace(est)
                let df = DateFormatter(); df.locale = Locale(identifier: "ja_JP"); df.dateFormat = "yyyy/MM/dd (E)"
                (df.string(from: day) as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: dayHeadingFont])
                y += 32
                drawGraph(dayLogs, originY: &y)
                y += 16
                // 2列配置 (行単位で高さ揃える)
                var idx = 0
                while idx < dayLogs.count {
                    let logA = dayLogs[idx]
                    let logB = (idx + 1 < dayLogs.count) ? dayLogs[idx+1] : nil
                    let hA = measureCard(logA, width: columnWidth)
                    let hB = logB.map { measureCard($0, width: columnWidth) } ?? 0
                    let rowH = max(hA, hB)
                    ensureSpace(rowH + rowSpacing)
                    _ = drawCard(logA, at: CGPoint(x: margin, y: y), width: columnWidth)
                    if let logB { _ = drawCard(logB, at: CGPoint(x: margin + columnWidth + columnGap, y: y), width: columnWidth) }
                    y += rowH + rowSpacing
                    idx += 2
                }
                y += 4
            }
            footer()
        }
        share(data: data, fileName: exportFileName(ext: "pdf"), uti: "com.adobe.pdf")
#endif
    }

    // MARK: - Helpers
    private func exportFileName(ext: String) -> String { let df = DateFormatter(); df.dateFormat = "yyyyMMdd_HHmm"; return "colinlog_\(df.string(from: Date())).\(ext)" }
    private func formattedLine(for log: ColinLog, markdown: Bool) -> String { let date = log.createdAt.colinISODate + " " + log.createdAt.colinTimeHHmm; let base = "[\(date)] Lv\(log.severity.rawValue) 発汗:\(log.sweating.label) 原因:\(log.triggerDescription) 対応:\(log.responseDescription)"; let detail = log.detail?.replacingOccurrences(of: "\n", with: markdown ? "<br>" : " "); let kind = log.kind == .memo ? " (メモ)" : ""; return base + (detail.map { " 詳細: \($0)" } ?? "") + kind }
    private func share(text: String, fileName: String) { if let data = text.data(using: .utf8) { share(data: data, fileName: fileName, uti: "public.plain-text") } }
    private func share(data: Data, fileName: String, uti: String) { let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName); do { try data.write(to: url, options: .atomic) } catch { return }; shareItems = [url]; showShare = true }
    private func setDefaultSelectionIfNeeded(forceAll: Bool = false) {
        guard outputMode == .specific else { return }
        if forceAll || selectedLogIDs.isEmpty { selectedLogIDs = Set(logs.map { $0.id }) }
    }
    private func ymd(_ d: Date) -> String {
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year,.month,.day], from: d)
        return String(format: "%04d/%02d/%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

// MARK: - Reusable Button
private struct ExportButton: View {
    let icon: String; let title: String; let subtitle: String; var tint: Color = .cyan; let disabled: Bool; let action: () -> Void
    var body: some View {
        Button(action: { if !disabled { action() } }) {
            HStack(spacing: 16) {
                ZStack { RoundedRectangle(cornerRadius: 14).fill(tint.opacity(disabled ? 0.25 : 0.9)); Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white) }
                    .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                Spacer(); Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 20).fill(.ultraThinMaterial).overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.07), lineWidth: 1)))
            .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#if canImport(UIKit)
import UIKit
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
private struct ActivityView: View { let items: [Any]; var body: some View { Text("共有未対応") } }
#endif

// アイコン画像取得 (ReportIcon をそのまま縮小描画)
#if canImport(UIKit)
private func appIconImage(size: CGFloat) -> UIImage? {
    guard let original = UIImage(named: "ReportIcon") else { return nil }
    if original.size.width == size && original.size.height == size { return original }
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    return renderer.image { ctx in
        ctx.cgContext.interpolationQuality = .high
        original.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
}
#endif

struct ExportView_Previews: PreviewProvider { static var previews: some View { ExportView().modelContainer(for: ColinLog.self, inMemory: true) } }
