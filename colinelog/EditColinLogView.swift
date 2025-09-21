// filepath: /Users/kazuki19992/gits/colinelog/colinelog/EditColinLogView.swift
// 既存コリンログ編集画面

import SwiftUI
import SwiftData

struct EditColinLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var log: ColinLog

    // 編集用一時フィールド (その他テキストは nil / 空 正規化)
    @State private var responseOther: String = ""
    @State private var triggerOther: String = ""

    @State private var date: Date = Date()

    // 初期化で現在値を State にコピー
    init(log: ColinLog) {
        self.log = log
        _date = State(initialValue: log.createdAt)
        _responseOther = State(initialValue: log.responseOtherNote ?? "")
        _triggerOther = State(initialValue: log.triggerOtherNote ?? "")
    }

    private var canSave: Bool {
        if log.response == .other && responseOther.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if log.trigger == .other && triggerOther.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                Section("強さ") { SeveritySelectorEdit(selected: $log.severity) }
                Section("対応") { responseSection }
                Section("メインの発症原因") { triggerSection }
                Section("発汗") { sweatingSection }
                Section("詳細") { detailSection }
            }
            .navigationTitle("編集")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { applyAndDismiss() }.disabled(!canSave) }
            }
        }
        .onAppear { syncStateFromModel() }
    }

    // MARK: Sections
    private var dateSection: some View {
        Section("日時") {
            ZStack(alignment: .leading) {
                DatePicker("日時", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .opacity(0.02)
                HStack(spacing: 12) {
                    badge(text: date.colinISODate)
                    badge(text: date.colinTimeHHmm)
                    Spacer()
                }.allowsHitTesting(false)
            }
        }
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.body.monospacedDigit())
            .padding(.vertical, 6).padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ResponseMenu(selection: $log.response)
            if log.response == .other { TextField("その他の内容", text: $responseOther) }
        }
    }

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TriggerMenu(selection: $log.trigger)
            if log.trigger == .other { TextField("その他のトリガー", text: $triggerOther) }
        }
    }

    private var sweatingSection: some View {
        Picker("発汗", selection: $log.sweating) {
            ForEach(ColinLog.SweatingLevel.allCases) { s in Text(s.label).tag(s) }
        }
        .pickerStyle(.segmented)
    }

    private var detailSection: some View {
        TextEditor(text: Binding(
            get: { log.detail ?? "" },
            set: { log.detail = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        ))
        .frame(minHeight: 120)
    }

    // MARK: Save
    private func applyAndDismiss() {
        log.createdAt = date
        log.responseOtherNote = log.response == .other ? responseOther.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        log.triggerOtherNote = log.trigger == .other ? triggerOther.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        // SwiftData は自動保存トランザクション。明示的保存が必要なら try? modelContext.save()
        dismiss()
    }

    private func syncStateFromModel() {
        responseOther = log.responseOtherNote ?? ""
        triggerOther = log.triggerOtherNote ?? ""
        date = log.createdAt
    }
}

// MARK: - Reusable Menus
private struct ResponseMenu: View {
    @Binding var selection: ColinLog.ResponseAction
    var body: some View {
        Menu {
            ForEach(ColinLog.ResponseAction.allCases) { r in
                Button(r.label) { selection = r }
            }
        } label: { MenuLabelEdit(text: selection.label) }
    }
}

private struct TriggerMenu: View {
    @Binding var selection: ColinLog.Trigger
    var body: some View {
        Menu {
            ForEach(ColinLog.Trigger.allCases) { t in
                Button(t.label) { selection = t }
            }
        } label: { MenuLabelEdit(text: selection.label) }
    }
}

private struct MenuLabelEdit: View {
    let text: String
    var body: some View {
        HStack {
            Text(text).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.down").font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Severity Selector (Edit)
private struct SeveritySelectorEdit: View {
    @Binding var selected: ColinLog.Severity
    var body: some View {
        HStack(spacing: 6) {
            ForEach(ColinLog.Severity.allCases) { s in
                let color = color(for: s)
                Button { selected = s } label: {
                    VStack(spacing: 2) {
                        Text("\(s.rawValue)").font(.caption2).bold()
                        Text(s.label).font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(selected == s ? color.opacity(0.9) : Color.secondary.opacity(0.15))
                    )
                    .overlay(
                        Capsule().stroke(selected == s ? color.opacity(0.95) : Color.secondary.opacity(0.3), lineWidth: selected == s ? 1.4 : 1)
                    )
                    .foregroundStyle(selected == s && color == .yellow ? Color.black : (selected == s ? Color.white : Color.primary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 2)
    }
    private func color(for s: ColinLog.Severity) -> Color {
        switch s {
        case .level1: return .blue
        case .level2: return Color(hue: 0.47, saturation: 0.65, brightness: 0.88)
        case .level3: return .yellow
        case .level4: return .orange
        case .level5: return .red
        }
    }
}

#Preview {
    // プレビュー用ダミー
    let log = ColinLog(severity: .level2, response: .coolSpray, trigger: .afterSweat, sweating: .moist)
    EditColinLogView(log: log)
        .modelContainer(for: ColinLog.self, inMemory: true)
}
