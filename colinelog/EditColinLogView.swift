// filepath: /Users/kazuki19992/gits/colinelog/colinelog/EditColinLogView.swift
// 既存コリンログ編集画面

import SwiftUI
import SwiftData

struct EditColinLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Bindable var log: ColinLog

    // ローカルドラフト (ビュー内で編集する一時コピー)
    private struct Draft {
        var createdAt: Date
        var severity: ColinLog.Severity
        var response: ColinLog.ResponseAction
        var responseOther: String
        var trigger: ColinLog.Trigger
        var triggerOther: String
        var sweating: ColinLog.SweatingLevel
        var detail: String
        var kind: ColinLog.Kind
    }

    @State private var draft: Draft
    @State private var previousKind: ColinLog.Kind

    // 初期化でモデルからドラフトへコピー
    init(log: ColinLog) {
        self.log = log
        let initial = Draft(
            createdAt: log.createdAt,
            severity: log.severity,
            response: log.response,
            responseOther: log.responseOtherNote ?? "",
            trigger: log.trigger,
            triggerOther: log.triggerOtherNote ?? "",
            sweating: log.sweating,
            detail: log.detail ?? "",
            kind: log.kind
        )
        _draft = State(initialValue: initial)
        _previousKind = State(initialValue: initial.kind)
    }

    private var canSave: Bool {
        if draft.kind == .memo { return true }
        if draft.response == .other && draft.responseOther.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if draft.trigger == .other && draft.triggerOther.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    private var kindBinding: Binding<ColinLog.Kind> {
        Binding(get: { draft.kind }, set: { draft.kind = $0 })
    }

    var body: some View {
        NavigationStack {
            Form {
                kindSection
                dateSection
                if draft.kind == .symptom {
                    Section("強さ") { SeveritySelectorEdit(selected: Binding(get: { draft.severity }, set: { draft.severity = $0 })) }
                    Section("対応") { responseSection }
                    Section("メインの発症原因") { triggerSection }
                    Section("発汗") { sweatingSection }
                }
                Section(draft.kind == .symptom ? "詳細" : "メモ") { detailSection }
            }
            .navigationTitle("編集")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { applyAndDismiss() }.disabled(!canSave) }
            }
        }
        .onAppear { syncStateFromModel() }
        .onChange(of: draft.kind) { _ in
            let newKind = draft.kind
            guard newKind != previousKind else { return }
            if newKind == .memo {
                draft.response = .none
                draft.responseOther = ""
                draft.trigger = .stressEmotion
                draft.triggerOther = ""
                draft.sweating = .none
                draft.severity = .level1
            } else {
                draft.severity = .level1
                draft.response = .none
                draft.trigger = .stressEmotion
                draft.sweating = .none
            }
            previousKind = newKind
        }
    }

    // MARK: Sections
    private var kindSection: some View {
        Section("種別") {
            Picker("種別", selection: kindBinding) {
                ForEach(ColinLog.Kind.allCases) { k in Text(k.label).tag(k) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var dateSection: some View {
        Section("日時") {
            ZStack(alignment: .leading) {
                DatePicker("日時", selection: Binding(get: { draft.createdAt }, set: { draft.createdAt = $0 }), displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .opacity(0.02)
                HStack(spacing: 12) {
                    badge(text: draft.createdAt.colinISODate)
                    badge(text: draft.createdAt.colinTimeHHmm)
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
            ResponseMenu(selection: Binding(get: { draft.response }, set: { draft.response = $0 }))
            if draft.response == .other { TextField("その他の内容", text: Binding(get: { draft.responseOther }, set: { draft.responseOther = $0 })) }
        }
    }

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TriggerMenu(selection: Binding(get: { draft.trigger }, set: { draft.trigger = $0 }))
            if draft.trigger == .other { TextField("その他のトリガー", text: Binding(get: { draft.triggerOther }, set: { draft.triggerOther = $0 })) }
        }
    }

    private var sweatingSection: some View {
        Picker("発汗", selection: Binding(get: { draft.sweating }, set: { draft.sweating = $0 })) {
            ForEach(ColinLog.SweatingLevel.allCases) { s in Text(s.label).tag(s) }
        }
        .pickerStyle(.segmented)
    }

    private var detailSection: some View {
        TextEditor(text: Binding(get: { draft.detail }, set: { draft.detail = $0 }))
        .frame(minHeight: 120)
    }

    // MARK: Save
    private func applyAndDismiss() {
        // draft -> model に反映
        log.createdAt = draft.createdAt
        log.kind = draft.kind
        log.severity = draft.severity
        log.response = draft.response
        log.responseOtherNote = draft.response == .other ? draft.responseOther.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        log.trigger = draft.trigger
        log.triggerOtherNote = draft.trigger == .other ? draft.triggerOther.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        log.sweating = draft.sweating
        let trimmedDetail = draft.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        log.detail = trimmedDetail.isEmpty ? nil : trimmedDetail

        dismiss()
    }

    private func syncStateFromModel() {
        // モデルの現在値をドラフトへ同期（onAppear のため）
        draft = Draft(
            createdAt: log.createdAt,
            severity: log.severity,
            response: log.response,
            responseOther: log.responseOtherNote ?? "",
            trigger: log.trigger,
            triggerOther: log.triggerOtherNote ?? "",
            sweating: log.sweating,
            detail: log.detail ?? "",
            kind: log.kind
        )
        previousKind = draft.kind
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
