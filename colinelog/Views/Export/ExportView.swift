import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ColinLog.createdAt, order: .reverse)]) private var logs: [ColinLog]

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
            .onAppear { resetSelectionAll() }
            .onChange(of: logs) { _, _ in resetSelectionAll() }
            .onChange(of: outputMode) { _, new in if new == .specific { resetSelectionAll() } }
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
        // ======= レイアウト設定 =======
        let pageWidth: CGFloat = 595.2  // A4 72dpi
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2
        let headerBottomSpace: CGFloat = 18
        let footerHeight: CGFloat = 30
        let graphHeight: CGFloat = 110
        let columnGap: CGFloat = 12
        let columnWidth = (contentWidth - columnGap)/2
        let rowVerticalSpacing: CGFloat = 5

        // フォント
        let fontTime = UIFont.monospacedSystemFont(ofSize: 9.5, weight: .regular)
        let fontSmall = UIFont.systemFont(ofSize: 8)
        let fontBullet = UIFont.systemFont(ofSize: 8)
        let fontBulletBold = UIFont.boldSystemFont(ofSize: 8)
        let fontDetail = UIFont.systemFont(ofSize: 8)
        let fontBadgeMain = UIFont.boldSystemFont(ofSize: 9)
        let fontBadgeSub = UIFont.systemFont(ofSize: 7)
        let lineSpacing: CGFloat = 2
        let bulletSpacing: CGFloat = 1.5

        // バッジ (幅縮小 & 角丸減少)
        let badgeWidth: CGFloat = 38
        let badgeHeight: CGFloat = 28
        let badgeCorner: CGFloat = 6
        let innerGap: CGFloat = 4
        let textAreaWidth: CGFloat = columnWidth - badgeWidth - innerGap

        // データグルーピング
        let cal = Calendar.current
        let grouped = Dictionary(grouping: target.sorted { $0.createdAt < $1.createdAt }) { cal.startOfDay(for: $0.createdAt) }
        let orderedDays = grouped.keys.sorted()
        let generatedDateString = ymd(Date())

        func severityBadgeColor(_ s: ColinLog.Severity) -> UIColor {
            switch s { case .level1: return .systemBlue; case .level2: return .systemTeal; case .level3: return .systemYellow; case .level4: return .systemOrange; case .level5: return .systemRed }
        }

        // 高さ計測
        func attrHeight(_ attr: NSAttributedString, width: CGFloat) -> CGFloat {
            let rect = attr.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin,.usesFontLeading], context: nil)
            return ceil(rect.height)
        }
        func bulletLine(label: String, value: String) -> NSAttributedString {
            let s = NSMutableAttributedString()
            s.append(NSAttributedString(string: "- \(label): ", attributes: [.font: fontBullet]))
            s.append(NSAttributedString(string: value, attributes: [.font: fontBulletBold]))
            return s
        }
        struct MeasuredLog { let log: ColinLog; let timeAttr: NSAttributedString; let bullets: [NSAttributedString]; let detailAttr: NSAttributedString?; let height: CGFloat }
        func measure(_ log: ColinLog) -> MeasuredLog {
            let timeAttr = NSAttributedString(string: log.createdAt.colinTimeHHmm, attributes: [.font: fontTime])
            var bullets: [NSAttributedString] = []
            if log.kind == .symptom {
                bullets = [
                    bulletLine(label: "原因", value: log.triggerDescription),
                    bulletLine(label: "対策", value: log.responseDescription),
                    bulletLine(label: "発汗", value: log.sweating.label)
                ]
            }
            let detailAttr: NSAttributedString? = (log.detail?.isEmpty == false) ? NSAttributedString(string: log.detail!, attributes: [.font: fontDetail]) : nil
            var h = attrHeight(timeAttr, width: textAreaWidth)
            if !bullets.isEmpty { h += lineSpacing }
            for (i,b) in bullets.enumerated() {
                h += attrHeight(b, width: textAreaWidth)
                if i < bullets.count - 1 { h += bulletSpacing }
            }
            if let d = detailAttr { h += lineSpacing + attrHeight(d, width: textAreaWidth) }
            h = max(h, badgeHeight) + 4
            return MeasuredLog(log: log, timeAttr: timeAttr, bullets: bullets, detailAttr: detailAttr, height: h)
        }

        func drawRoundedRect(_ rect: CGRect, radius: CGFloat, fill: UIColor) {
            let path = UIBezierPath(roundedRect: rect, cornerRadius: radius)
            fill.setFill(); path.fill()
        }

        func drawLog(_ m: MeasuredLog, at origin: CGPoint, width: CGFloat) {
            let log = m.log
            var x = origin.x
            let yTop = origin.y
            // バッジ
            let badgeRect = CGRect(x: x, y: yTop, width: badgeWidth, height: badgeHeight)
            let centerPara = NSMutableParagraphStyle(); centerPara.alignment = .center
            if log.kind == .memo {
                drawRoundedRect(badgeRect, radius: badgeCorner, fill: .systemGray)
                let memoAttr: [NSAttributedString.Key: Any] = [.font: fontBadgeMain, .foregroundColor: UIColor.white, .paragraphStyle: centerPara]
                ("メモ" as NSString).draw(in: CGRect(x: badgeRect.minX, y: badgeRect.minY + (badgeHeight - 12)/2, width: badgeRect.width, height: 14), withAttributes: memoAttr)
            } else {
                let color = severityBadgeColor(log.severity)
                drawRoundedRect(badgeRect, radius: badgeCorner, fill: color)
                let textColor: UIColor = (log.severity == .level3) ? .black : .white
                let numAttr: [NSAttributedString.Key: Any] = [.font: fontBadgeMain, .foregroundColor: textColor, .paragraphStyle: centerPara]
                let labelAttr: [NSAttributedString.Key: Any] = [.font: fontBadgeSub, .foregroundColor: textColor, .paragraphStyle: centerPara]
                ("\(log.severity.rawValue)" as NSString).draw(in: CGRect(x: badgeRect.minX, y: badgeRect.minY + 4, width: badgeRect.width, height: 12), withAttributes: numAttr)
                (log.severity.label as NSString).draw(in: CGRect(x: badgeRect.minX, y: badgeRect.minY + 16, width: badgeRect.width, height: 10), withAttributes: labelAttr)
            }
            // テキスト部
            x += badgeWidth + innerGap
            let textWidth = width - badgeWidth - innerGap
            var cursorY = yTop
            m.timeAttr.draw(with: CGRect(x: x, y: cursorY, width: textWidth, height: 40), options: [.usesLineFragmentOrigin,.usesFontLeading], context: nil)
            cursorY += attrHeight(m.timeAttr, width: textWidth)
            if !m.bullets.isEmpty { cursorY += lineSpacing }
            for (i,b) in m.bullets.enumerated() {
                b.draw(with: CGRect(x: x, y: cursorY, width: textWidth, height: 200), options: [.usesLineFragmentOrigin,.usesFontLeading], context: nil)
                cursorY += attrHeight(b, width: textWidth) + (i < m.bullets.count - 1 ? bulletSpacing : 0)
            }
            if let d = m.detailAttr { cursorY += lineSpacing; d.draw(with: CGRect(x: x, y: cursorY, width: textWidth, height: 1000), options: [.usesLineFragmentOrigin,.usesFontLeading], context: nil) }
        }

        func drawGraph(for day: Date, logs: [ColinLog], in ctx: UIGraphicsPDFRendererContext, y: inout CGFloat) {
            let rect = CGRect(x: margin, y: y, width: contentWidth, height: graphHeight)
            let bg = UIBezierPath(roundedRect: rect, cornerRadius: 9)
            UIColor(white:0.97, alpha:1).setFill(); bg.fill()
            UIColor(white:0.85, alpha:1).setStroke(); bg.lineWidth = 1; bg.stroke()
            let g = UIGraphicsGetCurrentContext()!
            // タイトル用上部余白 (レベル5ラベルとの衝突回避)
            let topTitlePadding: CGFloat = 16 // タイトル領域
            // グラフ有効高さ (下側マージン20を既存計算と合わせつつ上部を追加オフセット)
            let effectiveHeight = rect.height - 20 - topTitlePadding
            g.setStrokeColor(UIColor(white:0.9, alpha:1).cgColor); g.setLineWidth(0.4)
            for i in 0...5 {
                let ly = rect.minY + 6 + topTitlePadding + CGFloat(i) * (effectiveHeight / 5)
                g.move(to: CGPoint(x: rect.minX + 38, y: ly))
                g.addLine(to: CGPoint(x: rect.maxX - 6, y: ly))
            }
            g.strokePath()
            for i in 1...5 {
                let s = "\(i)" as NSString
                s.draw(at: CGPoint(
                    x: rect.minX + 22 - s.size(withAttributes: [.font: fontSmall]).width/2,
                    y: rect.maxY - 14 - CGFloat(i)*(effectiveHeight)/5 - 4
                ), withAttributes: [.font: fontSmall, .foregroundColor: UIColor.darkGray])
            }
            let times = [0,6,12,18,24]
            for t in times {
                let lbl = String(format: "%02d:00", t) as NSString
                let attr:[NSAttributedString.Key:Any] = [.font: UIFont.systemFont(ofSize:6.5), .foregroundColor:UIColor.darkGray]
                let xPos = rect.minX + 38 + CGFloat(t)/24*(rect.width - 50)
                lbl.draw(at: CGPoint(x: xPos - lbl.size(withAttributes: attr).width/2, y: rect.maxY - 12), withAttributes: attr)
            }
            for lg in logs where lg.kind == .symptom {
                let secs = cal.component(.hour, from: lg.createdAt)*3600 + cal.component(.minute, from: lg.createdAt)*60 + cal.component(.second, from: lg.createdAt)
                let ratio = CGFloat(secs)/86400
                let barX = rect.minX + 38 + ratio*(rect.width - 50)
                let barMaxH = effectiveHeight - 6 // 余白微調整
                let barH = barMaxH * CGFloat(lg.severity.rawValue)/5
                let barRect = CGRect(x: barX - 2.4, y: rect.maxY - 14 - barH, width: 4.8, height: barH)
                severityUIColor(for: lg.severity.rawValue).setFill(); UIBezierPath(roundedRect: barRect, cornerRadius: 1.8).fill()
            }
            // タイトルは余白内上部へ
            ("症状レベル推移" as NSString).draw(at: CGPoint(x: rect.minX + 8, y: rect.minY + 4), withAttributes: [.font:UIFont.systemFont(ofSize:9), .foregroundColor:UIColor.darkGray])
            y += graphHeight
        }

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let data = renderer.pdfData { ctx in
            var pageNumber = 0
            var y: CGFloat = 0
            func header() {
                pageNumber += 1; ctx.beginPage(); y = margin
                if let icon = appIconImage(size: 42) { icon.draw(in: CGRect(x: margin, y: y, width: 42, height: 42)) }
                let titleX = margin + 52
                let title = "コリン性蕁麻疹 症状レポート (生成日: \(generatedDateString))" as NSString
                title.draw(at: CGPoint(x: titleX, y: y + 2), withAttributes: [.font:UIFont.boldSystemFont(ofSize:14)])
                ("ユーザー名" as NSString).draw(at: CGPoint(x: titleX, y: y + 24), withAttributes: [.font:UIFont.systemFont(ofSize:10), .foregroundColor:UIColor.darkGray])
                y += 48
                let g = UIGraphicsGetCurrentContext()!; g.setStrokeColor(UIColor.black.cgColor); g.setLineWidth(0.5); g.move(to: CGPoint(x: margin, y: y)); g.addLine(to: CGPoint(x: pageWidth - margin, y: y)); g.strokePath(); y += headerBottomSpace
            }
            func footer() {
                let g = UIGraphicsGetCurrentContext()!; g.setStrokeColor(UIColor.black.cgColor); g.setLineWidth(0.5); g.move(to: CGPoint(x: margin, y: pageHeight - footerHeight)); g.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - footerHeight)); g.strokePath()
                ("Generated By コリンログ" as NSString).draw(at: CGPoint(x: margin, y: pageHeight - footerHeight + 8), withAttributes: [.font:UIFont.systemFont(ofSize:8), .foregroundColor:UIColor.darkGray])
                let p = "p.\(pageNumber)" as NSString; let attr:[NSAttributedString.Key:Any] = [.font:UIFont.systemFont(ofSize:8), .foregroundColor:UIColor.darkGray]; let s = p.size(withAttributes: attr); p.draw(at: CGPoint(x: pageWidth - margin - s.width, y: pageHeight - footerHeight + 8), withAttributes: attr)
            }
            func ensureSpace(_ needed: CGFloat) { if y + needed + footerHeight + 4 > pageHeight { footer(); header() } }

            header()
            for day in orderedDays {
                guard let dayLogs = grouped[day] else { continue }
                let df = DateFormatter(); df.locale = Locale(identifier: "ja_JP"); df.dateFormat = "yyyy/MM/dd (E)"
                let heading = df.string(from: day) as NSString
                ensureSpace(24)
                heading.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font:UIFont.boldSystemFont(ofSize:12.5)])
                y += 20
                ensureSpace(graphHeight + 6)
                drawGraph(for: day, logs: dayLogs, in: ctx, y: &y)
                y += 6
                // ---- 2カラム縦流し (左→右) ----
                let measured = dayLogs.map { measure($0) }
                var leftY = y
                var rightY = y
                let usableBottom = pageHeight - footerHeight - 4
                var usedRightColumn = false
                func newPageForContinuation(includeGraph: Bool) {
                    footer(); header()
                    // 日付見出し(続き)
                    let contHeading = heading
                    contHeading.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font:UIFont.boldSystemFont(ofSize:12.5)])
                    y += 20
                    leftY = y; rightY = y; usedRightColumn = false
                }
                for m in measured {
                    // 現在の描画ターゲット列を選ぶ (左優先)
                    var targetIsLeft = !usedRightColumn
                    // フィット判定
                    func fitsLeft() -> Bool { leftY + m.height <= usableBottom }
                    func fitsRight() -> Bool { rightY + m.height <= usableBottom }
                    if targetIsLeft {
                        if !fitsLeft() { // 左に入らない→右へ移動
                            usedRightColumn = true
                            targetIsLeft = false
                            if !fitsRight() { // 右にも入らない→改ページ
                                newPageForContinuation(includeGraph: false)
                                targetIsLeft = true
                            }
                        }
                    } else { // 右列利用中
                        if !fitsRight() { // 右が溢れる→新ページ
                            newPageForContinuation(includeGraph: false)
                            targetIsLeft = true
                        }
                    }
                    // 描画
                    if targetIsLeft {
                        drawLog(m, at: CGPoint(x: margin, y: leftY), width: columnWidth)
                        leftY += m.height + rowVerticalSpacing
                    } else {
                        drawLog(m, at: CGPoint(x: margin + columnWidth + columnGap, y: rightY), width: columnWidth)
                        rightY += m.height + rowVerticalSpacing
                    }
                    if !usedRightColumn && !targetIsLeft { usedRightColumn = true }
                }
                // 日セクション終了後の y を最大列位置に更新
                y = max(leftY, rightY) + 2
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
    private func resetSelectionAll() { selectedLogIDs = Set(logs.map { $0.id }) }
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

#if canImport(UIKit)
private func severityUIColor(for level: Int) -> UIColor {
    switch level {
    case 1: return UIColor.systemBlue
    case 2: return UIColor.systemTeal
    case 3: return UIColor.systemYellow
    case 4: return UIColor.systemOrange
    default: return UIColor.systemRed
    }
}
#endif

struct ExportView_Previews: PreviewProvider { static var previews: some View { ExportView().modelContainer(for: ColinLog.self, inMemory: true) } }
