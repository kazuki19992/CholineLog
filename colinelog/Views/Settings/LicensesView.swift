import SwiftUI

struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var licenses: [[String: Any]] = []

    var body: some View {
        List {
            if licenses.isEmpty {
                VStack(spacing: 12) {
                    Text("ライセンス情報が見つかりません")
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button(action: loadLicenses) {
                            Text("再読み込み")
                        }
                        Button(action: { dismiss() }) {
                            Text("閉じる")
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(licenses.indices, id: \.self) { idx in
                    let item = licenses[idx]
                    VStack(alignment: .leading, spacing: 6) {
                        Text((item["name"] as? String) ?? (item["project"] as? String) ?? "Unknown")
                            .font(.headline)
                        if let license = item["license"] as? String {
                            Text(license)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(5)
                        } else if let text = item["text"] as? String {
                            Text(text)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(5)
                        }
                        HStack {
                            if let version = item["version"] as? String {
                                Text("Version: \(version)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if let url = item["url"] as? String {
                                Text(url)
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .navigationTitle("ライセンス")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("閉じる") { dismiss() }
            }
        }
        .onAppear(perform: loadLicenses)
    }

    private func findLicensesInBundle() -> URL? {
        if let url = Bundle.main.url(forResource: "Licenses", withExtension: "json") {
            return url
        }
        if let resURL = Bundle.main.resourceURL {
            let fm = FileManager.default
            if let enumerator = fm.enumerator(at: resURL, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    if fileURL.lastPathComponent.lowercased() == "licenses.json" {
                        return fileURL
                    }
                }
            }
        }
        return nil
    }

    private func loadLicenses() {
        guard let url = findLicensesInBundle() else {
            #if DEBUG
            print("Licenses.json がバンドルに見つかりません")
            #endif
            licenses = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let obj = try JSONSerialization.jsonObject(with: data, options: [])
            if let arr = obj as? [[String: Any]] {
                licenses = arr
            } else if let dict = obj as? [String: Any] {
                if let arr = dict["licenses"] as? [[String: Any]] {
                    licenses = arr
                } else {
                    licenses = [dict]
                }
            }
        } catch {
            #if DEBUG
            print("Licenses.json の読み込みに失敗: \(error)")
            #endif
            licenses = []
        }
    }
}

struct LicensesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LicensesView()
        }
    }
}
