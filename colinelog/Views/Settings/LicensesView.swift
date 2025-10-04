import SwiftUI

private struct LicenseEntry: Identifiable, Codable {
    let id: UUID
    let name: String
    let text: String

    init(id: UUID = UUID(), name: String, text: String) {
        self.id = id
        self.name = name
        self.text = text
    }
}

struct LicensesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var licenses: [LicenseEntry] = []
    @State private var selected: LicenseEntry? = nil

    var body: some View {
        NavigationStack {
            Group {
                if licenses.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("ライセンス情報が見つかりませんでした")
                            .font(.headline)
                        Text("Bundle に Licenses.json を追加するか、依存ライブラリのライセンスファイルがバンドルに含まれていることを確認してください。")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding()
                    }
                    .padding()
                } else {
                    List(licenses) { entry in
                        Button(action: { selected = entry }) {
                            HStack {
                                Text(entry.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("ライセンス")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { Task { await loadLicenses() } }
            .sheet(item: $selected) { entry in
                NavigationStack {
                    ScrollView {
                        Text(entry.text)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle(entry.name)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { selected = nil } } }
                }
            }
        }
    }

    private func loadLicenses() async {
        // First: try well-known JSON files in main bundle
        let jsonCandidates = ["Licenses", "ThirdPartyLicenses", "ThirdPartyAcknowledgements"]
        let dec = JSONDecoder()
        for name in jsonCandidates {
            if let url = Bundle.main.url(forResource: name, withExtension: "json") {
                if let data = try? Data(contentsOf: url), let decoded = try? dec.decode([LicenseEntry].self, from: data) {
                    await MainActor.run { licenses = decoded }
                    return
                }
            }
        }

        // Perform bundle scanning off the main actor using DispatchQueue
        let foundPairs: [(String, String)] = await withCheckedContinuation { (continuation: CheckedContinuation<[(String, String)], Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var results: [(String, String)] = []
                let fm = FileManager.default

                // Collect bundles (keep order but dedupe by identifier/path)
                var allBundles = [Bundle.main]
                allBundles.append(contentsOf: Bundle.allBundles)
                allBundles.append(contentsOf: Bundle.allFrameworks)
                var seen = Set<String>()
                var uniqueBundles: [Bundle] = []
                for b in allBundles {
                    let id = b.bundleIdentifier ?? "<anon>:\(b.bundlePath)"
                    if !seen.contains(id) {
                        seen.insert(id)
                        uniqueBundles.append(b)
                    }
                }

                let filenameCandidates = ["LICENSE", "LICENSE.txt", "LICENSE.md", "COPYING", "NOTICE"]

                for bundle in uniqueBundles {
                    let displayName = (bundle.infoDictionary?["CFBundleName"] as? String) ?? bundle.bundleIdentifier ?? "Unknown"

                    // direct resource lookups
                    for cand in filenameCandidates {
                        if let url = bundle.url(forResource: cand, withExtension: nil) ?? bundle.url(forResource: cand, withExtension: "txt") ?? bundle.url(forResource: cand, withExtension: "md") {
                            if let text = try? String(contentsOf: url) {
                                results.append((displayName, text))
                            }
                        }
                    }

                    // scan resource directory
                    if let resourcePath = bundle.resourcePath, let items = try? fm.contentsOfDirectory(atPath: resourcePath) {
                        for item in items {
                            let lower = item.lowercased()
                            if lower.contains("license") || lower.contains("notice") || lower == "copying" {
                                let full = URL(fileURLWithPath: resourcePath).appendingPathComponent(item)
                                if let text = try? String(contentsOf: full) {
                                    results.append((displayName, text))
                                }
                            }
                        }
                    }
                }

                // Deduplicate by (name + text)
                var uniqueResults: [(String, String)] = []
                var seen2 = Set<String>()
                for (n, t) in results {
                    let key = n + "\u{1F}" + t
                    if !seen2.contains(key) {
                        seen2.insert(key)
                        uniqueResults.append((n, t))
                    }
                }

                continuation.resume(returning: uniqueResults)
            }
        }

        if !foundPairs.isEmpty {
            await MainActor.run {
                licenses = foundPairs.map { LicenseEntry(name: $0.0, text: $0.1) }
            }
            return
        }

        // Fallback: try LICENSES.txt splitting by marker (main bundle)
        if let txtURL = Bundle.main.url(forResource: "LICENSES", withExtension: "txt"), let raw = try? String(contentsOf: txtURL) {
            let parts = raw.components(separatedBy: "\n----\n")
            await MainActor.run {
                licenses = parts.enumerated().map { idx, part in
                    LicenseEntry(name: "ライセンス \(idx + 1)", text: part)
                }
            }
            return
        }

        // nothing found -> leave empty
    }
}

// Simple helper to uniquify an array by key
extension Array {
    func unique<T: Hashable>(_ key: (Element) -> T) -> [Element] {
        var seen = Set<T>()
        var out: [Element] = []
        for e in self {
            let k = key(e)
            if !seen.contains(k) {
                seen.insert(k)
                out.append(e)
            }
        }
        return out
    }
}
