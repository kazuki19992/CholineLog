import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// インポート用DTO (View外に出して非 MainActor 化)
fileprivate struct ImportRow: Codable, Sendable {
    // DTO: enum 値は rawValue の String として受け取り、後で main actor 側で変換する
    let createdAt: String // ISO8601 文字列 (数値が与えられた場合は ISO8601 に変換して格納)
    let severity: Int
    let response: String
    let trigger: String
    let sweating: String
    let detail: String?
    let kind: String
    let rash: String?

    enum CodingKeys: String, CodingKey {
        case createdAt, severity, response, trigger, sweating, detail, kind, rash
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // createdAt: string または number を許容
        if let s = try? c.decode(String.self, forKey: .createdAt) {
            createdAt = s
        } else if let d = try? c.decode(Double.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: d))
        } else if let i = try? c.decode(Int.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: TimeInterval(i)))
        } else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: c, debugDescription: "createdAt must be ISO8601 string or unix time number")
        }

        // severity: integer 1..5 または 数値文字列
        if let n = try? c.decode(Int.self, forKey: .severity) {
            severity = n
        } else if let s = try? c.decode(String.self, forKey: .severity), let n = Int(s) {
            severity = n
        } else {
            throw DecodingError.dataCorruptedError(forKey: .severity, in: c, debugDescription: "severity must be integer 1..5 or numeric string")
        }

        // 列挙値は文字列のまま保持
        response = (try? c.decode(String.self, forKey: .response)) ?? ""
        trigger = (try? c.decode(String.self, forKey: .trigger)) ?? ""
        sweating = (try? c.decode(String.self, forKey: .sweating)) ?? ""
        detail = try? c.decodeIfPresent(String.self, forKey: .detail)
        kind = (try? c.decode(String.self, forKey: .kind)) ?? ""
        // rash: null または 文字列
        if try c.decodeNil(forKey: .rash) {
            rash = nil
        } else {
            rash = try? c.decodeIfPresent(String.self, forKey: .rash)
        }
    }
}

fileprivate struct ImportRoot: Codable, Sendable {
    let schemaVersion: Int?
    let rows: [ImportRow]

    enum CodingKeys: String, CodingKey {
        case schemaVersion, rows
    }

    // Provide an explicit nonisolated initializer to avoid main-actor-isolated synthesized Decodable in Swift 6 mode
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try? c.decodeIfPresent(Int.self, forKey: .schemaVersion)
        rows = try c.decode([ImportRow].self, forKey: .rows)
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showImporter = false
    @State private var showLicenses = false
    @State private var showTips = false // 追加
    @State private var importError: String? = nil
    @State private var importSuccessCount: Int? = nil
    @State private var importSkippedCount: Int? = nil // 追加: スキップ件数
    @State private var importSkipSummary: String? = nil // 追加: スキップ理由概要
    @State private var showDeleteConfirm = false
    @State private var deleteError: String? = nil
    @State private var deleteSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section("データ") {
                    Button { showImporter = true } label: {
                        Label("JSONインポート", systemImage: "square.and.arrow.down")
                    }
                    .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { handleImport($0) }
                    Button {
                        // 全データ削除: 確認ダイアログを表示
                        showDeleteConfirm = true
                    } label: {
                        Label("すべてのデータの削除", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
                Section("アプリ") {
                    Button { showLicenses = true } label: {
                        Label("ライセンス", systemImage: "doc.plaintext")
                    }
                    Button { showTips = true } label: {
                        Label("コリンログにチップを贈る", systemImage: "gift")
                    }
                    HStack () {
                        Label("アプリバージョン", systemImage: "gear")
                        Spacer()
                        Text (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "不明")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("設定")
            .alert("インポート結果", isPresented: Binding(get: { importSuccessCount != nil }, set: { if !$0 { importSuccessCount = nil; importSkippedCount = nil; importSkipSummary = nil } })) {
                Button("OK", role: .cancel) { importSuccessCount = nil; importSkippedCount = nil; importSkipSummary = nil }
            } message: {
                let success = importSuccessCount ?? 0
                let skipped = importSkippedCount ?? 0
                VStack(alignment: .leading, spacing: 4) {
                    Text("成功: \(success) 件")
                    if skipped > 0 { Text("スキップ: \(skipped) 件").foregroundStyle(.secondary) }
                    if let sum = importSkipSummary { Text(sum).font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .alert("インポートエラー", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
                Button("OK", role: .cancel) { importError = nil }
            } message: { Text(importError ?? "") }
            // 削除確認アラート
            .alert("全データを消そうとしています!!", isPresented: $showDeleteConfirm) {
                Button("削除", role: .destructive) { deleteAllData() }
                Button("キャンセル", role: .cancel) { showDeleteConfirm = false }
            } message: {
                Text("一度消したデータは戻りません。\n本当に消していいですか？")
            }
            // 削除結果アラート (成功)
            .alert("完了", isPresented: $deleteSuccess) {
                Button("OK", role: .cancel) { deleteSuccess = false }
            } message: { Text("全てのデータを削除しました。") }
            // 削除エラーアラート
            .alert("削除エラー", isPresented: Binding(get: { deleteError != nil }, set: { if !$0 { deleteError = nil } })) {
                Button("OK", role: .cancel) { deleteError = nil }
            } message: { Text(deleteError ?? "") }
            .fullScreenCover(isPresented: $showLicenses) {
                LicensesView()
            }
            .fullScreenCover(isPresented: $showTips) { TipsView() }
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

    private func importJSON(from url: URL) async {
        let decodedResult: Result<[ImportRow], Error> = await Task.detached(priority: .userInitiated) {
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }

            // まずシンプル読込
            var data: Data? = try? Data(contentsOf: url)
            if data == nil { // FileCoordinator フォールバック
                var coordErr: NSError?
                NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordErr) { safeURL in
                    data = try? Data(contentsOf: safeURL)
                }
                if let coordErr { return .failure(coordErr) }
            }
            guard let data else { return .failure(NSError(domain: "Import", code: 1, userInfo: [NSLocalizedDescriptionKey: "データ取得失敗 (size=0)" ])) }

            let decoder = JSONDecoder()

            func tryDecode(_ d: Data) -> Result<[ImportRow], Error> {
                // パターン1: 直接配列（スキーマに忠実な ImportRow にデコード）
                if let rows = try? decoder.decode([ImportRow].self, from: d) { return .success(rows) }
                // パターン2: ルートオブジェクト { schemaVersion?: 1, rows: [...] } を厳密に扱う
                if let root = try? decoder.decode(ImportRoot.self, from: d) {
                    if let v = root.schemaVersion, v != 1 {
                        return .failure(NSError(domain: "Import", code: 4, userInfo: [NSLocalizedDescriptionKey: "unsupported schemaVersion: \(v)"]))
                    }
                    return .success(root.rows)
                }
                return .failure(NSError(domain: "Import", code: 2, userInfo: [NSLocalizedDescriptionKey: "デコード試行失敗 (スキーマに準拠していません) "]))
            }

            // 1) まず生データで試す
            // closure を async にするため軽い非同期操作を入れる
            await Task.yield()
            let rawAttempt = tryDecode(data)
            if case .success = rawAttempt { return rawAttempt }

            // 2) 失敗したら文字列として読み取り、先頭のコメントやブロックコメントを削除して再試行
            if var s = String(data: data, encoding: .utf8) {
                // BOM除去
                if s.hasPrefix("\u{feff}") { s.removeFirst() }
                // 行コメント //... を削除 (行頭のもの)
                s = s.replacingOccurrences(of: "(?m)^\\s*//.*$\\n?", with: "", options: .regularExpression)
                // ブロックコメント /* ... */ を削除 (DOTALL を inline (?s) で有効化)
                s = s.replacingOccurrences(of: "(?s)/\\*.*?\\*/", with: "", options: .regularExpression)
                // 余分なカンマなどでパース不能になるケースを過度に修正しないよう注意しつつ再挑戦
                if let cleanedData = s.data(using: .utf8) {
                    let cleanedAttempt = tryDecode(cleanedData)
                    if case .success = cleanedAttempt { return cleanedAttempt }
                }
            }

            // 3) 詳細エラーを生成して返す
            let head = String(data: data.prefix(300), encoding: .utf8) ?? "(バイナリ)"
            let msg = "JSON解析失敗: 期待形式: 配列 [ { ... } ] 又は { \"rows\": [ ... ] }\n先頭300文字:\n\(head)"
            let nserr = NSError(domain: "Import", code: 3, userInfo: [NSLocalizedDescriptionKey: msg])
            return .failure(nserr)
         }.value

        switch decodedResult {
        case .failure(let err):
            await MainActor.run { importError = "読み込み失敗: \(err.localizedDescription)" }
        case .success(let rows):
            await MainActor.run {
                let iso = ISO8601DateFormatter()
                var success = 0
                var skipped = 0
                var skipReasons: [String] = []
                for (idx, r) in rows.enumerated() {
                    // createdAt は ISO8601 文字列で来る想定 (数値はデコーダで変換済み)
                    guard let date = iso.date(from: r.createdAt) else { skipped += 1; skipReasons.append("#\(idx+1) 日付不正: \(r.createdAt)"); continue }
                    // severity は Int -> ColinLog.Severity へ変換
                    guard let severity = ColinLog.Severity(rawValue: r.severity) else { skipped += 1; skipReasons.append("#\(idx+1) severity不正: \(r.severity)"); continue }
                    // 文字列からモデルの列挙型へ変換
                    guard let responseEnum = ColinLog.ResponseAction(rawValue: r.response) else { skipped += 1; skipReasons.append("#\(idx+1) response不正: \(r.response)"); continue }
                    guard let triggerEnum = ColinLog.Trigger(rawValue: r.trigger) else { skipped += 1; skipReasons.append("#\(idx+1) trigger不正: \(r.trigger)"); continue }
                    guard let sweatingEnum = ColinLog.SweatingLevel(rawValue: r.sweating) else { skipped += 1; skipReasons.append("#\(idx+1) sweating不正: \(r.sweating)"); continue }
                    guard let kindEnum = ColinLog.Kind(rawValue: r.kind) else { skipped += 1; skipReasons.append("#\(idx+1) kind不正: \(r.kind)"); continue }
                    // rash はオプショナル
                    let rashEnum: ColinLog.RashLevel = {
                        if let rs = r.rash {
                            return ColinLog.RashLevel(rawValue: rs) ?? .noRash
                        } else { return .noRash }
                    }()
                    let log = ColinLog(createdAt: date, severity: severity, response: responseEnum, trigger: triggerEnum, sweating: sweatingEnum, detail: r.detail, kind: kindEnum, rash: rashEnum)
                     modelContext.insert(log)
                     success += 1
                 }
                do {
                    try modelContext.save()
                    importSuccessCount = success
                    importSkippedCount = skipped
                    if !skipReasons.isEmpty {
                        let head = skipReasons.prefix(5).joined(separator: "\n")
                        let more = skipReasons.count > 5 ? "\n他 \(skipReasons.count - 5) 件" : ""
                        importSkipSummary = head + more
                    } else {
                        importSkipSummary = nil
                    }
                } catch {
                    importError = "保存失敗: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Delete All Data
    private func deleteAllData() {
        // 非同期で実行し、メインアクター上で modelContext を操作する
        Task { await MainActor.run {
            do {
                let all: [ColinLog] = try modelContext.fetch(FetchDescriptor<ColinLog>())
                for item in all { modelContext.delete(item) }
                try modelContext.save()
                deleteSuccess = true
            } catch {
                deleteError = "削除失敗: \(error.localizedDescription)"
            }
            // 確認ダイアログを閉じる
            showDeleteConfirm = false
        } }
    }
}
