import SwiftUI

struct LicenseEntry: Identifiable, Decodable {
    let id: String
    let name: String
    let text: String

    // カスタムキー (スクリプト将来拡張で name/text 以外が来ても頑健に)
    enum CodingKeys: String, CodingKey { case id, name, text, project, license }

    init(id: String, name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // id が無い場合は生成
        let id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        // name または project
        let name = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .project))
            ?? "Unknown"
        // text または license フィールド
        let text = (try? c.decode(String.self, forKey: .text))
            ?? (try? c.decode(String.self, forKey: .license))
            ?? ""
        self.init(id: id, name: name, text: text)
    }
}

struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var licenses: [LicenseEntry] = []
    @State private var loadError: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if licenses.isEmpty && loadError != nil {
                    VStack(spacing: 8) {
                        Text("ライセンス情報の取得に失敗しました")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Text(loadError ?? "不明なエラー")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Text("アプリに Licenses.json が含まれているかビルド設定を確認してください。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if licenses.isEmpty {
                    ProgressView("読み込み中…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(licenses) { item in
                        NavigationLink(destination: LicenseDetailView(entry: item)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.name)
                                    .font(.headline)
                                Text(item.text.prefix(300) + (item.text.count > 300 ? "…" : ""))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                    .lineLimit(5)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("ライセンス")
            .toolbar { toolbar }
            .task { await loadLicenses() }
        }
    }

    private func findLicensesInBundle() -> URL? {
        if let url = Bundle.main.url(forResource: "Licenses", withExtension: "json") {
            return url
        }
        if let resURL = Bundle.main.resourceURL {
            let fm = FileManager.default
            if let enumerator = fm.enumerator(at: resURL, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator where fileURL.lastPathComponent.lowercased() == "licenses.json" {
                    return fileURL
                }
            }
        }
        return nil
    }

    @MainActor
    private func assignResult(_ result: Result<[LicenseEntry], Error>) {
        switch result {
        case .success(let entries):
            self.licenses = entries
            self.loadError = entries.isEmpty ? "Licenses.json にエントリがありません" : nil
        case .failure(let err):
            self.licenses = []
            self.loadError = err.localizedDescription
        }
    }

    private func decodeFallback(data: Data) throws -> [LicenseEntry] {
        // 旧実装 (辞書配列) との後方互換
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        var out: [LicenseEntry] = []
        switch obj {
        case let arr as [[String: Any]]:
            for d in arr {
                let id = (d["id"] as? String) ?? UUID().uuidString
                let name = (d["name"] as? String) ?? (d["project"] as? String) ?? "Unknown"
                let text = (d["text"] as? String) ?? (d["license"] as? String) ?? ""
                out.append(.init(id: id, name: name, text: text))
            }
        case let dict as [String: Any]:
            if let arr = dict["licenses"] as? [[String: Any]] {
                return try decodeFallback(data: JSONSerialization.data(withJSONObject: arr, options: []))
            } else {
                let id = (dict["id"] as? String) ?? UUID().uuidString
                let name = (dict["name"] as? String) ?? (dict["project"] as? String) ?? "Unknown"
                let text = (dict["text"] as? String) ?? (dict["license"] as? String) ?? ""
                out.append(.init(id: id, name: name, text: text))
            }
        default: break
        }
        return out
    }

    private func loadLicenses() async {
        guard let url = findLicensesInBundle() else {
            #if DEBUG
            print("Licenses.json がバンドルに見つかりません")
            #endif
            await MainActor.run { self.assignResult(.failure(NSError(domain: "Licenses", code: 1, userInfo: [NSLocalizedDescriptionKey: "Licenses.json が見つかりません"])) ) }
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let entries: [LicenseEntry]
            if let decoded = try? decoder.decode([LicenseEntry].self, from: data) {
                entries = decoded
            } else {
                entries = try decodeFallback(data: data)
            }
            await MainActor.run { self.assignResult(.success(entries)) }
        } catch {
            #if DEBUG
            print("Licenses.json の読み込みに失敗: \(error)")
            #endif
            await MainActor.run { self.assignResult(.failure(error)) }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { dismiss() }) { Text("閉じる") }
        }
    }
}

struct LicenseDetailView: View {
    let entry: LicenseEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(entry.name)
                    .font(.title2.bold())
                Text(entry.text)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(entry.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { Button("閉じる") { dismiss() } }
        }
    }
}

struct LicensesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { LicensesView() }
    }
}
