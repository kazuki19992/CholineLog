import Foundation
import SwiftUI
import SwiftData
import Combine

// MARK: - Export 機能用 ViewModel
//   役割:
//     1. UI状態(@Published)の保持
//     2. ログ抽出(選択/期間/種類フィルタ)
//     3. 各フォーマットへのエクスポート指揮 (生成自体は別ヘルパ)
//     4. 共有用一時ファイル生成
@MainActor
final class ExportViewModel: ObservableObject {
    // MARK: Nested Types
    enum ExportFormat { case text, markdown, json, pdf }
    enum OutputMode: String, CaseIterable, Identifiable {
        case specific
        case filtered
        var id: String { rawValue }
        var label: String { self == .specific ? "特定のログ" : "期間と種類" }
    }
    enum PeriodMode: String, CaseIterable, Identifiable {
        case all
        case range
        var id: String { rawValue }
        var label: String { self == .all ? "すべて" : "期間指定" }
    }

    // MARK: Published UI State
    @Published var logs: [ColinLog] = []
    @Published var outputMode: OutputMode = .specific
    @Published var periodMode: PeriodMode = .all
    @Published var startDate: Date = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    @Published var endDate: Date = Date()
    @Published var includeSymptom: Bool = true
    @Published var includeMemo: Bool = true
    @Published var selectedLogIDs: Set<ColinLog.ID> = []
    @Published var showingFormat: Bool = false
    @Published private(set) var chosenFormat: ExportFormat? = nil
    @Published var shareItems: [Any] = []
    @Published var showShare: Bool = false

    // MARK: Derived
    var exportTarget: [ColinLog] { previewSelection() }
    var canExport: Bool { !exportTarget.isEmpty }

    // MARK: External Events
    func setLogs(_ newLogs: [ColinLog]) {
        logs = newLogs
        if outputMode == .specific { resetSelectionAll() }
    }
    func onChangeOutputMode(_ new: OutputMode) {
        if new == .specific { resetSelectionAll() }
    }

    // MARK: Selection Logic
    private func previewSelection() -> [ColinLog] {
        switch outputMode {
        case .specific:
            return logs.filter { selectedLogIDs.contains($0.id) }
        case .filtered:
            var base = logs
            if periodMode == .range {
                let cal = Calendar.current
                let startDay = cal.startOfDay(for: startDate)
                let endDay = cal.date(
                    bySettingHour: 23,
                    minute: 59,
                    second: 59,
                    of: endDate
                ) ?? endDate
                base = base.filter { $0.createdAt >= startDay && $0.createdAt <= endDay }
            }
            return base.filter {
                (includeSymptom && $0.kind == .symptom) || (includeMemo && $0.kind == .memo)
            }
        }
    }

    func toggleSelection(_ log: ColinLog) {
        if selectedLogIDs.contains(log.id) {
            selectedLogIDs.remove(log.id)
        } else { selectedLogIDs.insert(log.id) }
    }
    func toggleSelectAll() {
        if selectedLogIDs.count == logs.count { selectedLogIDs.removeAll() }
        else { selectedLogIDs = Set(logs.map { $0.id }) }
    }
    func resetSelectionAll() { selectedLogIDs = Set(logs.map { $0.id }) }

    // MARK: Export Flow
    func chooseAndExport(_ format: ExportFormat) { chosenFormat = format; runExport() }
    private func runExport() {
        guard let format = chosenFormat, !exportTarget.isEmpty else { return }
        switch format {
        case .text: exportPlainText(exportTarget)
        case .markdown: exportMarkdown(exportTarget)
        case .json: exportJSON(exportTarget)
        case .pdf: exportPDF(exportTarget)
        }
        chosenFormat = nil; showingFormat = false
    }

    // MARK: Generators
    private func exportPlainText(_ target: [ColinLog]) {
        let sorted = sortLogs(target)
        let body = sorted.map {
            formattedLog(for: $0, markdown: false)
        }.joined(separator: "\n")
        share(text: body, fileName: exportFileName(ext: "txt"))
    }
    private func exportMarkdown(_ target: [ColinLog]) {
        var md = "# コリンログエクスポート\n\n件数: \(target.count)\n\n"
        var prevDay: String? = nil
        // 最新を最後にソート
        let sorted = sortLogs(target)
        
        sorted.forEach { log in
            let currentDay = log.createdAt.colinISODate
            if prevDay != currentDay { md += "## \(currentDay)\n\n" }
            prevDay = currentDay
            md += formattedLog(for: log, markdown: true) + "\n"
            md += "---\n"
        }
        share(text: md, fileName: exportFileName(ext: "md"))
    }
    private struct JSONRow: Codable {
        let createdAt: String; let severity: Int; let response: String; let trigger: String
        let sweating: String; let detail: String?; let kind: String
    }
    private func exportJSON(_ target: [ColinLog]) {
        let iso = ISO8601DateFormatter()
        let rows = target.map { log in JSONRow(
            createdAt: iso.string(from: log.createdAt),
            severity: log.severity.rawValue,
            response: log.response.rawValue,
            trigger: log.trigger.rawValue,
            sweating: log.sweating.rawValue,
            detail: log.detail,
            kind: log.kind.rawValue)
        }
        if let data = try? JSONEncoder().encode(rows) {
            share(data: data, fileName: exportFileName(ext: "json"), uti: "public.json")
        }
    }
    private func exportPDF(_ target: [ColinLog]) {
        #if canImport(UIKit)
        if let data = ExportPDFGenerator.generate(logs: target) {
            share(
                data: data,
                fileName: exportFileName(ext: "pdf"),
                uti: "com.adobe.pdf"
            )
        }
        #endif
    }

    // MARK: Share Helpers
    private func share(text: String, fileName: String) {
        guard let data = text.data(using: .utf8) else { return }
        share(data: data, fileName: fileName, uti: "public.plain-text")
    }
    private func share(data: Data, fileName: String, uti: String) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do { try data.write(to: url, options: .atomic) } catch { return }
        shareItems = [url]; showShare = true
    }

    // MARK: Helpers
    private func exportFileName(ext: String) -> String {
        let df = DateFormatter(); df.dateFormat = "yyyyMMdd_HHmm"
        return "colinlog_\(df.string(from: Date())).\(ext)"
    }
    private func formattedLog(for log: ColinLog, markdown: Bool) -> String {
        markdown ? getFormattedMarkdown(for: log) : getFormattedPlainText(for: log)
    }
    private func getFormattedMarkdown(for log: ColinLog) -> String {
        let time = "### " + log.createdAt.colinTimeHHmm
        if log.kind == .symptom {
            let level = "- Lv.\(log.severity.rawValue)"
            let sweating = "- 発汗: \(log.sweating.label)"
            let trigger = "- 原因: \(log.triggerDescription)"
            let response = "- 対応: \(log.responseDescription)"
            let detail = log.detail?.replacingOccurrences(of: "\n\n", with: "\n")
            return [time, level, sweating, trigger, response,
                    detail.map { "- 詳細: \($0)" } ?? nil]
                .compactMap { $0 }.joined(separator: "\n")
        } else {
            let memo = "メモ"
            let detail = log.detail?.replacingOccurrences(of: "\n\n", with: "\n")
            return [time, memo, detail.map { "- 詳細: \($0)" } ?? nil]
                .compactMap { $0 }.joined(separator: "\n")
        }
    }
    private func getFormattedPlainText(for log: ColinLog) -> String {
        let date = log.createdAt.colinISODate + " " + log.createdAt.colinTimeHHmm
        if log.kind == .symptom {
            let level = "- Lv.\(log.severity.rawValue)"
            let sweating = "- 発汗: \(log.sweating.label)"
            let trigger = "- 原因: \(log.triggerDescription)"
            let response = "- 対応: \(log.responseDescription)"
            let detail = log.detail
            return [date, level, sweating, trigger, response,
                    detail.map { "- 詳細: \($0)" } ?? nil]
                .compactMap { $0 }.joined(separator: "\n")
        } else {
            let memo = "メモ"
            let detail = log.detail
            return [date, memo, detail.map { "- 詳細: \($0)" } ?? nil]
                .compactMap { $0 }.joined(separator: "\n")
        }
    }
    private func sortLogs(_ logs: [ColinLog]) -> [ColinLog] {
        // 最新を最後になるようにソートする
        return logs.sorted { $0.createdAt < $1.createdAt }
    }
    func ymd(_ d: Date) -> String {
        let c = Calendar(identifier: .gregorian).dateComponents([.year,.month,.day], from: d)
        return String(format: "%04d/%02d/%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
