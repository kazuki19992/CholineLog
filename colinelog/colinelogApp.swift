//
//  colinelogApp.swift
//  colinelog
//
//  Created by 櫛田一樹 on 2025/09/21.
//

import SwiftUI
import SwiftData

@main
struct colinelogApp: App {
    init() {
#if canImport(UIKit)
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundColor = .clear
        nav.backgroundEffect = nil
        let accent = UIColor(red: 0.0, green: 0.675, blue: 0.922, alpha: 1.0)
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = accent
        UITabBar.appearance().tintColor = accent
        UITabBar.appearance().unselectedItemTintColor = UIColor.systemGray
        UITableView.appearance().backgroundColor = .clear
        UITableViewCell.appearance().backgroundColor = .clear
#endif
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ColinLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.cyan)
        }
        .modelContainer(sharedModelContainer)
    }
}
