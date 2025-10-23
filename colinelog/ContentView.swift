//
//  ContentView.swift
//  colinelog
//
//  Created by 櫛田一樹 on 2025/09/21.
//

import SwiftUI
import SwiftData

private enum MainTab: Hashable { case overview, logs, export, settings, add }

struct ContentView: View {
    @State private var selection: MainTab = .overview
    @State private var lastNonAddSelection: MainTab = .overview
    @State private var showAddSheet = false
    // マイグレーション用
    @Environment(\.modelContext) private var modelContext
    @State private var migrationResultCount: Int? = nil
    @State private var showMigrationAlert = false
    var body: some View {
        TabView(selection: $selection) {
            OverviewView()
                .tabItem { Label("概要", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(MainTab.overview)
            LogsView()
                .tabItem { Label("コリンログ", systemImage: "list.bullet.rectangle") }
                .tag(MainTab.logs)
            ExportView()
                .tabItem { Label("書き出し", systemImage: "square.and.arrow.up") }
                .tag(MainTab.export)
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
        .task {
            // 一度だけ実行
            if migrationResultCount == nil {
                let updated = DataMigrations.fixNilRashIfNeeded(context: modelContext)
                migrationResultCount = updated
                if updated > 0 { showMigrationAlert = true }
            }
        }
        .alert("データ移行完了", isPresented: $showMigrationAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Rash の nil フィールドを \(migrationResultCount ?? 0) 件更新しました")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ColinLog.self], inMemory: true)
}
