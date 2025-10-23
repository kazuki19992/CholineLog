// filepath: /Users/kazuki19992/gits/colinelog/colinelog/EditColinLogView.swift
// 既存コリンログ編集画面

import SwiftUI
import SwiftData

struct EditColinLogView: View {
    @Bindable var log: ColinLog
    var body: some View {
        NavigationStack { ColinLogFormView(mode: .edit(log: log)) }
    }
}

#Preview {
    let log = ColinLog(severity: .level2, response: .coolSpray, trigger: .afterSweat, sweating: .moist)
    EditColinLogView(log: log)
        .modelContainer(for: ColinLog.self, inMemory: true)
}
