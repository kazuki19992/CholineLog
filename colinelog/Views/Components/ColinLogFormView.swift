import SwiftUI
import SwiftData

// 共通ドラフトモデル
struct ColinLogDraft: Equatable {
    var createdAt: Date = Date()
    var severity: ColinLog.Severity = .level1
    var response: ColinLog.ResponseAction = .none
    var responseOther: String = ""
    var trigger: ColinLog.Trigger = .stressEmotion
    var triggerOther: String = ""
    var sweating: ColinLog.SweatingLevel = .none
    var detail: String = ""
    var kind: ColinLog.Kind = .symptom
    var rash: ColinLog.RashLevel = .noRash

    init() {}
    init(from log: ColinLog) {
        createdAt = log.createdAt
        severity = log.severity
        response = log.response
        responseOther = log.responseOtherNote ?? ""
        trigger = log.trigger
        triggerOther = log.triggerOtherNote ?? ""
        sweating = log.sweating
        detail = log.detail ?? ""
        kind = log.kind
        rash = log.rash
    }
    func buildNewModel() -> ColinLog {
        ColinLog(
            createdAt: createdAt,
            severity: severity,
            response: response,
            responseOtherNote: response == .other ? trimmedOrNil(responseOther) : nil,
            trigger: trigger,
            triggerOtherNote: trigger == .other ? trimmedOrNil(triggerOther) : nil,
            sweating: sweating,
            detail: trimmedOrNil(detail),
            kind: kind,
            rash: rash
        )
    }
    func apply(to log: ColinLog) {
        log.createdAt = createdAt
        log.kind = kind
        log.severity = severity
        log.response = response
        log.responseOtherNote = response == .other ? trimmedOrNil(responseOther) : nil
        log.trigger = trigger
        log.triggerOtherNote = trigger == .other ? trimmedOrNil(triggerOther) : nil
        log.sweating = sweating
        log.detail = trimmedOrNil(detail)
        log.rash = rash
    }
    private func trimmedOrNil(_ s: String) -> String? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? nil : t
    }
}

enum ColinLogFormMode {
    case create
    case edit(log: ColinLog)
}

struct ColinLogFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: ColinLogFormMode
    // 完了後のコールバック（成功時 true）
    var onComplete: ((Bool) -> Void)? = nil

    @State private var draft: ColinLogDraft
    @State private var previousKind: ColinLog.Kind
    @State private var saveErrorMessage: String? = nil

    init(mode: ColinLogFormMode, onComplete: ((Bool)->Void)? = nil) {
        self.mode = mode
        self.onComplete = onComplete
        switch mode {
        case .create:
            let d = ColinLogDraft()
            _draft = State(initialValue: d)
            _previousKind = State(initialValue: d.kind)
        case .edit(let log):
            let d = ColinLogDraft(from: log)
            _draft = State(initialValue: d)
            _previousKind = State(initialValue: d.kind)
        }
    }

    // 保存ボタン活性判定
    private var canSave: Bool {
        if draft.kind == .memo { return true }
        if draft.response == .other && draft.responseOther.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if draft.trigger == .other && draft.triggerOther.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    var body: some View {
        Form {
            kindSection
            dateSection
            if draft.kind == .symptom {
                Section("強さ") { severitySection }
                Section("主な原因と対応") {
                    HStack {
                        Text("原因").font(.caption)
                        Spacer()
                        triggerSection
                    }
                    HStack {
                        Text("対応").font(.caption)
                        Spacer()
                        responseSection
                    }
                }
                Section("肌の状態") {
                    VStack (alignment: .leading, spacing: 24) {
                        HStack {
                            Text("発汗").font(.caption);
                            Spacer();
                            sweatingSection
                        }
                        HStack {
                            Text("発疹").font(.caption);
                            Spacer();
                            rashSection
                        }
                    }
                    
                }
            }
            Section(draft.kind == .symptom ? "詳細" : "メモ") { detailSection }
        }
        .navigationTitle(modeTitle)
        .toolbarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .onChange(of: draft.kind) { _ in adjustForKindChange() }
        .alert("保存エラー", isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: { Text(saveErrorMessage ?? "") }
    }

    private var modeTitle: String { switch mode { case .create: return "コリンログを追加"; case .edit: return "編集" } }

    // MARK: Sections
    private var kindSection: some View {
        Section("種別") {
            Picker("種別", selection: $draft.kind) {
                ForEach(ColinLog.Kind.allCases) { k in Text(k.label).tag(k) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var dateSection: some View {
        Section("日時") {
            ZStack(alignment: .leading) {
                DatePicker("日時", selection: $draft.createdAt, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .opacity(0.02)
                HStack(spacing: 12) {
                    dateBadge(text: draft.createdAt.colinISODate)
                    dateBadge(text: draft.createdAt.colinTimeHHmm)
                    Spacer()
                }.allowsHitTesting(false)
            }
        }
    }
    private func dateBadge(text: String) -> some View {
        Text(text)
            .font(.body.monospacedDigit())
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(Color.secondary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var severitySection: some View {
        SeveritySelectorUnified(selected: $draft.severity)
            .padding(.vertical, 2)
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(ColinLog.ResponseAction.allCases) { r in
                    Button(r.label) { draft.response = r }
                }
            } label: { ColoredMenuLabelUnified(text: draft.response.label, color: draft.response.color, leadingSystemName: draft.response.iconSystemName) }
            if draft.response == .other { TextField("その他の内容", text: $draft.responseOther) }
        }
    }

    private var triggerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Menu {
                ForEach(ColinLog.Trigger.allCases) { t in
                    Button(t.label) { draft.trigger = t }
                }
            } label: { ColoredMenuLabelUnified(text: draft.trigger.label, color: draft.trigger.color, leadingSystemName: draft.trigger.iconSystemName) }
            if draft.trigger == .other { TextField("その他のトリガー", text: $draft.triggerOther) }
        }
    }

    private var sweatingSection: some View {
        Picker("発汗", selection: $draft.sweating) {
            ForEach(ColinLog.SweatingLevel.allCases) { s in Text(s.label).tag(s) }
        }
        .pickerStyle(.segmented)
    }

    private var rashSection: some View {
        Picker("発疹", selection: $draft.rash) {
            ForEach(ColinLog.RashLevel.allCases) { r in
                Text(r.label).tag(r)
            }
        }
        .pickerStyle(.segmented)
    }

    private var detailSection: some View {
        TextEditor(text: $draft.detail)
            .frame(minHeight: 120)
    }

    // MARK: Toolbar
    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) { Button("閉じる") { onComplete?(false); dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
            Button("保存") { save() }
                .disabled(!canSave)
        }
    }

    private func save() {
        switch mode {
        case .create:
            let new = draft.buildNewModel()
            modelContext.insert(new)
            do { try modelContext.save(); onComplete?(true); dismiss() } catch { saveErrorMessage = error.localizedDescription }
        case .edit(let log):
            draft.apply(to: log)
            do { try modelContext.save(); onComplete?(true); dismiss() } catch { saveErrorMessage = error.localizedDescription }
        }
    }

    private func adjustForKindChange() {
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

// 共通 Severity セレクタ
private struct SeveritySelectorUnified: View {
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

// 色付きメニューラベル共通
private struct ColoredMenuLabelUnified: View {
    let text: String
    let color: Color
    var leadingSystemName: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            if let leading = leadingSystemName {
                Image(systemName: leading)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }
            Text(text).foregroundColor(color).lineLimit(1)
            Spacer()
            Image(systemName: "chevron.down").font(.caption).foregroundStyle(color.opacity(0.7))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.15), value: text)
    }
}

#Preview("Create") {
    NavigationStack {
        ColinLogFormView(mode: .create)
            .modelContainer(for: ColinLog.self, inMemory: true)
    }
}

#Preview("Edit") {
    let log = ColinLog(severity: .level2, response: .coolSpray, trigger: .afterSweat, sweating: .moist)
    NavigationStack {
        ColinLogFormView(mode: .edit(log: log))
            .modelContainer(for: ColinLog.self, inMemory: true)
    }
}
