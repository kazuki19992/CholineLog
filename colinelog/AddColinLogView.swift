// filepath: /Users/kazuki19992/gits/colinelog/colinelog/AddColinLogView.swift
// コリンログ追加画面

import SwiftUI
import SwiftData

struct AddColinLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date: Date = Date()
    @State private var severity: ColinLog.Severity = .level1
    @State private var response: ColinLog.ResponseAction = .none
    @State private var responseOther: String = ""
    @State private var trigger: ColinLog.Trigger = .stressEmotion
    @State private var triggerOther: String = ""
    @State private var sweating: ColinLog.SweatingLevel = .none
    @State private var detail: String = ""

    private var canSave: Bool {
        if response == .other && responseOther.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        if trigger == .other && triggerOther.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                strengthSection
                responseSection
                triggerSection
                sweatingSection
                detailSection
            }
            .navigationTitle("コリンログを追加")
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: save) {
                        Text("保存").bold()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.accentColor)
                    .disabled(!canSave)
                    .accessibilityLabel("コリンログを保存")
                }
            }
        }
    }

    // MARK: セクション分割
    private var dateSection: some View {
        Section("日時") {
            ZStack(alignment: .leading) {
                DatePicker("日時", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .opacity(0.02)
                    .accessibilityLabel("日時選択")
                HStack(spacing: 12) {
                    dateBadge(text: date.colinISODate)
                    dateBadge(text: date.colinTimeHHmm)
                    Spacer(minLength: 0)
                }
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
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

    private var strengthSection: some View {
        Section("強さ") { SeveritySelector(selected: $severity) }
    }

    private var responseSection: some View {
        Section("対応") {
            ResponseMenuView(selection: $response)
            if response == .other { TextField("その他の内容", text: $responseOther) }
        }
    }

    private var triggerSection: some View {
        Section("メインの発症原因") {
            TriggerMenuView(selection: $trigger)
            if trigger == .other { TextField("その他のトリガー", text: $triggerOther) }
        }
    }

    private var sweatingSection: some View {
        Section("発汗") {
            Picker("発汗", selection: $sweating) {
                ForEach(ColinLog.SweatingLevel.allCases) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var detailSection: some View {
        Section("詳細") {
            TextEditor(text: $detail)
                .frame(minHeight: 120)
        }
    }

    private func save() {
        let log = ColinLog(
            createdAt: date,
            severity: severity,
            response: response,
            responseOtherNote: response == .other ? responseOther.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            trigger: trigger,
            triggerOtherNote: trigger == .other ? triggerOther.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
            sweating: sweating,
            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : detail
        )
        modelContext.insert(log)
        dismiss()
    }
}

// 個別色付き 2段レイアウト擬似セグメント
private struct SeveritySelector: View {
    @Binding var selected: ColinLog.Severity

    var body: some View {
        HStack(spacing: 6) {
            ForEach(ColinLog.Severity.allCases) { s in
                let color = color(for: s)
                SeverityPill(severity: s, color: color, isSelected: s == selected) {
                    selected = s
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func color(for s: ColinLog.Severity) -> Color {
        switch s {
        case .level1: return .blue
        case .level2: return Color(hue: 0.47, saturation: 0.65, brightness: 0.88) // 青→黄 中間
        case .level3: return .yellow
        case .level4: return .orange
        case .level5: return .red
        }
    }
}

private struct SeverityPill: View {
    let severity: ColinLog.Severity
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(severity.rawValue)")
                    .font(.caption2).bold()
                Text(severity.label)
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.9) : Color.secondary.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? color.opacity(0.95) : Color.secondary.opacity(0.3), lineWidth: isSelected ? 1.4 : 1)
            )
            .foregroundStyle(isSelected ? (color == .yellow ? Color.black : Color.white) : Color.primary)
            .contentShape(Capsule())
            .accessibilityLabel("強さ \(severity.rawValue) \(severity.label)" + (isSelected ? " 選択中" : ""))
            .animation(nil, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - フル幅メニュー共通ラベル
private struct MenuLabel: View {
    let text: String
    var body: some View {
        HStack {
            Text(text)
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.down")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - 対応メニュー
private struct ResponseMenuView: View {
    @Binding var selection: ColinLog.ResponseAction
    var body: some View {
        Menu {
            ForEach(ColinLog.ResponseAction.allCases) { r in
                Button(r.label) { selection = r }
            }
        } label: { MenuLabel(text: selection.label) }
    }
}

// MARK: - メイントリガーメニュー
private struct TriggerMenuView: View {
    @Binding var selection: ColinLog.Trigger
    var body: some View {
        Menu {
            ForEach(ColinLog.Trigger.allCases) { t in
                Button(t.label) { selection = t }
            }
        } label: { MenuLabel(text: selection.label) }
    }
}

#Preview {
    AddColinLogView()
        .modelContainer(for: ColinLog.self, inMemory: true)
}
