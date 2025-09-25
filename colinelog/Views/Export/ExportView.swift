import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ExportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\ColinLog.createdAt, order: .reverse)]) private var logs: [ColinLog]
    
    // ViewModel
    @StateObject private var vm = ExportViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    selectionInline
                    selectionSummary
                }
                .padding(.top, 32)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("書き出し")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("次へ") { vm.showingFormat = true }.disabled(!vm.canExport) } }
            .sheet(isPresented: $vm.showShare) { ActivityView(items: vm.shareItems) }
            .sheet(isPresented: $vm.showingFormat) { formatSheet }
            .onAppear { vm.setLogs(logs); vm.resetSelectionAll() }
            .onChange(of: logs) { _, new in vm.setLogs(new) }
            .onChange(of: vm.outputMode) { _, new in vm.onChangeOutputMode(new) }
        }
        .tint(.cyan)
    }
    
    // MARK: - インライン選択 UI
    private var selectionInline: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("エクスポート対象を選択")
                .font(.headline)
            
            // モード切替
            Picker("", selection: $vm.outputMode) {
                ForEach(ExportViewModel.OutputMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            
            Group {
                switch vm.outputMode {
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
            if vm.logs.isEmpty {
                Text("ログがありません").font(.caption).foregroundStyle(.secondary)
            } else {
                HStack {
                    let allSelected = !vm.logs.isEmpty && vm.selectedLogIDs.count == vm.logs.count
                    Button(allSelected ? "すべて解除" : "すべて選択") { vm.toggleSelectAll() }
                        .font(.caption)
                    Spacer()
                    Text("選択: \(vm.selectedLogIDs.count)件").font(.caption).foregroundStyle(.secondary)
                }
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(vm.logs) { log in
                        Button(action: { vm.toggleSelection(log) }) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: vm.selectedLogIDs.contains(log.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(vm.selectedLogIDs.contains(log.id) ? .cyan : .secondary)
                                    .padding(.top, 6)
                                ColinLogRow(log: log)
                                    .contentShape(Rectangle())
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if vm.selectedLogIDs.isEmpty { Text("少なくとも1件選択してください").font(.caption2).foregroundStyle(.red) }
            }
        }
    }
    
    private var filteredInlineControls: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 期間
            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $vm.periodMode) {
                    ForEach(ExportViewModel.PeriodMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if vm.periodMode == .range {
                    DatePicker("開始", selection: $vm.startDate, displayedComponents: .date)
                    DatePicker("終了", selection: $vm.endDate, displayedComponents: .date)
                    if vm.startDate > vm.endDate { Text("開始日は終了日以前にしてください").font(.caption2).foregroundStyle(.red) }
                }
            }
            // 種類
            VStack(alignment: .leading, spacing: 8) {
                Toggle("症状ログ", isOn: $vm.includeSymptom)
                Toggle("メモ", isOn: $vm.includeMemo)
                if !vm.includeSymptom && !vm.includeMemo { Text("少なくとも1つ選択してください").font(.caption2).foregroundStyle(.red) }
            }
            // プレビュー
            VStack(alignment: .leading, spacing: 4) {
                Text("プレビュー (\(vm.exportTarget.count)件)").font(.subheadline.bold())
                if vm.exportTarget.isEmpty { Text("条件に合うログがありません").font(.caption).foregroundStyle(.secondary) }
                else {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(vm.exportTarget.prefix(20)) { log in
                            ColinLogRow(log: log)
                                .padding(.vertical, 4)
                        }
                    }
                    if vm.exportTarget.count > 20 { Text("… 他 \(vm.exportTarget.count - 20) 件").font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
    }
    
    // MARK: - サマリー
    private var selectionSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("現在の対象")
                .font(.headline)
            if vm.exportTarget.isEmpty {
                Text(vm.outputMode == .specific ? "ログを選択してください" : "条件を調整してください")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("件数: \(vm.exportTarget.count)").font(.subheadline.bold())
                if vm.outputMode == .filtered {
                    let periodText: String = {
                        if vm.periodMode == .all { return "期間: すべて" }
                        return "期間: " + vm.ymd(vm.startDate) + " ~ " + vm.ymd(vm.endDate)
                    }()
                    Text(periodText).font(.caption).foregroundStyle(.secondary)
                    let kinds = [vm.includeSymptom ? "症状ログ" : nil, vm.includeMemo ? "メモ" : nil].compactMap { $0 }.joined(separator: ", ")
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
                Text("対象: \(vm.exportTarget.count) 件").font(.caption).foregroundStyle(.secondary)
                VStack(spacing: 14) {
                    ExportButton(icon: "doc.plaintext", title: "テキスト", subtitle: "通常のテキスト形式で出力します", disabled: false) { vm.chooseAndExport(.text) }
                    ExportButton(icon: "text.alignleft", title: "Markdown", subtitle: "ChatGPTへの共有やドキュメント作成に便利です", disabled: false) { vm.chooseAndExport(.markdown) }
                    ExportButton(icon: "curlybraces", title: "JSON", subtitle: "データのバックアップに最適です", disabled: false) { vm.chooseAndExport(.json) }
                    ExportButton(icon: "doc.richtext", title: "PDF", subtitle: "印刷してお医者さんに見せることができます", disabled: false) { vm.chooseAndExport(.pdf) }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .navigationTitle("書き出し形式")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { vm.showingFormat = false } } }
        }
        .tint(.cyan)
    }
}

// MARK: - Reusable Button
private struct ExportButton: View {
    let icon: String;
    let title: String;
    let subtitle: String;
    var tint: Color = .cyan;
    let disabled: Bool;
    let action: () -> Void
    var body: some View {
        Button(action: {
            if !disabled {
                action()
            }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(tint.opacity(disabled ? 0.25 : 0.9));
                    Image(systemName: icon).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                }.frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline);
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer();
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.secondary)
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
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#else
private struct ActivityView: View { let items: [Any]; var body: some View { Text("共有未対応") } }
#endif

struct ExportView_Previews: PreviewProvider {
    static var previews: some View { ExportView().modelContainer(for: ColinLog.self, inMemory: true) }
}
