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
                    Button {
                        showImporter = true
                    } label: {
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

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let err):
            importError = "読み込み失敗: \(err.localizedDescription)"
        case .success(let url):
            do {
                let data = try Data(contentsOf: url)
                struct J: Codable { let createdAt: String; let severity: Int; let response: String; let trigger: String; let sweating: String; let detail: String?; let kind: String }
                let arr = try JSONDecoder().decode([J].self, from: data)
                let iso = ISO8601DateFormatter()
                var count = 0
                for item in arr {
                    guard let date = iso.date(from: item.createdAt),
                          let severity = ColinLog.Severity(rawValue: item.severity),
                          let response = ColinLog.ResponseAction(rawValue: item.response),
                          let trigger = ColinLog.Trigger(rawValue: item.trigger),
                          let sweating = ColinLog.SweatingLevel(rawValue: item.sweating),
                          let kind = ColinLog.Kind(rawValue: item.kind) else { continue }
                    let log = ColinLog(createdAt: date, severity: severity, response: response, trigger: trigger, sweating: sweating, detail: item.detail, kind: kind)
                    modelContext.insert(log)
                    count += 1
                }
                try modelContext.save()
                importSuccessCount = count
            } catch {
                importError = "JSON解析失敗: \(error.localizedDescription)"
            }
        }
    }
}
