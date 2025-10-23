// filepath: /Users/kazuki19992/gits/colinelog/colinelog/AddColinLogView.swift
// コリンログ追加画面

import SwiftUI
import SwiftData

struct AddColinLogView: View {
    var body: some View {
        NavigationStack { ColinLogFormView(mode: .create) }
    }
}

#Preview {
    AddColinLogView().modelContainer(for: ColinLog.self, inMemory: true)
}
