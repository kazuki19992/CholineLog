import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showImporter = false
    @State private var importError: String? = nil
    @State private var importSuccessCount: Int? = nil

    var body: some View {
        NavigationStack {
            Form {
                Section("一般") {
                    Label("設定 (準備中)", systemImage: "gear")
                }
                Section("データ") {
                    Button { showImporter = true } label: {
                        Label("JSONインポート", systemImage: "square.and.arrow.down")
                    }
                    .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { handleImport($0) }
                }
            }
            .navigationTitle("設定")
            .alert("インポート結果", isPresented: Binding(get: { importSuccessCount != nil }, set: { if !$0 { importSuccessCount = nil } })) {
                Button("OK", role: .cancel) { importSuccessCount = nil }
            } message: { Text("\(importSuccessCount ?? 0) 件読み込みました") }
            .alert("インポートエラー", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) { importError = nil }
            } message: { Text(importError ?? "") }
        }
    }

    // MARK: - Import
    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let err):
            importError = "読み込み失敗: \(err.localizedDescription)"
        case .success(let url):
            importJSON(from: url)
        }
    }

    private struct ImportRow: Codable {
        let createdAt: String
        let severity: Int
        let response: String
        let trigger: String
        let sweating: String
        let detail: String?
        let kind: String
    }

    private func importJSON(from url: URL) {
        // security-scoped resource 対応
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

        // iCloud 未ダウンロードの場合のダウンロード試行
        if FileManager.default.isUbiquitousItem(at: url) {
            _ = try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }

        // FileCoordinator で読み込み (エラー詳細取得)
        var readError: NSError?
        var data: Data?
        NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &readError) { safeURL in
            data = try? Data(contentsOf: safeURL)
        }
        if let readError { importError = "読み込み権限エラー: \(readError.localizedDescription)"; return }
        guard let data else { importError = "データ取得失敗"; return }

        // JSON Decode (ISO8601 + フォールバック)
        let decoder = JSONDecoder()
        do {
            let rows = try decoder.decode([ImportRow].self, from: data)
            let iso = ISO8601DateFormatter()
            var success = 0
            for r in rows {
                guard let date = iso.date(from: r.createdAt),
                      let severity = ColinLog.Severity(rawValue: r.severity),
                      let response = ColinLog.ResponseAction(rawValue: r.response),
                      let trigger = ColinLog.Trigger(rawValue: r.trigger),
                      let sweating = ColinLog.SweatingLevel(rawValue: r.sweating),
                      let kind = ColinLog.Kind(rawValue: r.kind) else { continue }
                let log = ColinLog(
                    createdAt: date,
                    severity: severity,
                    response: response,
                    trigger: trigger,
                    sweating: sweating,
                    detail: r.detail,
                    kind: kind
                )
                modelContext.insert(log)
                success += 1
            }
            try modelContext.save()
            importSuccessCount = success
        } catch {
            importError = "JSON解析失敗: \(error.localizedDescription)"
        }
    }
}
