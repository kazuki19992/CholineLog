import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showImporter = false
    @State private var showLicenses = false
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
                Section("アプリ") {
                    Button { showLicenses = true } label: {
                        Label("ライセンス", systemImage: "doc.plaintext")
                    }
                    HStack () {
                        Label("アプリバージョン", systemImage: "gear",)
                        Spacer()
                        Text (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .alert("インポート結果", isPresented: Binding(get: { importSuccessCount != nil }, set: { if !$0 { importSuccessCount = nil } })) {
                Button("OK", role: .cancel) { importSuccessCount = nil }
            } message: { Text("\(importSuccessCount ?? 0) 件読み込みました") }
            .alert("インポートエラー", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) { importError = nil }
            } message: { Text(importError ?? "") }
            .fullScreenCover(isPresented: $showLicenses) {
                LicensesView()
            }
        }
    }

    // MARK: - Import
    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let err):
            importError = "読み込み失敗: \(err.localizedDescription)"
        case .success(let url):
            Task(priority: .userInitiated) { await importJSON(from: url) }
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

    private func importJSON(from url: URL) async {
        // Heavy I/O and decoding performed off the main actor
        let decodedResult: Result<[ImportRow], Error> = await Task.detached(priority: .userInitiated) {
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
            if let readError { return .failure(readError) }
            guard let data else { return .failure(NSError(domain: "Import", code: 1, userInfo: [NSLocalizedDescriptionKey: "データ取得失敗"])) }

            // JSON Decode
            let decoder = JSONDecoder()
            do {
                let rows = try decoder.decode([ImportRow].self, from: data)
                return .success(rows)
            } catch {
                return .failure(error)
            }
        }.value

        // Handle result on MainActor: mutate modelContext and update UI state
        switch decodedResult {
        case .failure(let err):
            await MainActor.run { importError = "読み込み失敗: \(err.localizedDescription)" }
        case .success(let rows):
            await MainActor.run {
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
                do {
                    try modelContext.save()
                    importSuccessCount = success
                } catch {
                    importError = "保存失敗: \(error.localizedDescription)"
                }
            }
        }
    }
}
