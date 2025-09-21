import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Form {
                Section("一般") {
                    Label("設定 (準備中)", systemImage: "gear")
                }
            }
            .navigationTitle("設定")
        }
    }
}