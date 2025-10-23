import Foundation
import SwiftUI
import Combine // 追加

@MainActor
final class LogsViewModel: ObservableObject {
    // 将来フィルタや検索を拡張するためのプレースホルダ
    @Published var searchText: String = ""
    func filtered(_ logs: [ColinLog]) -> [ColinLog] {
        guard !searchText.isEmpty else { return logs }
        return logs.filter { ($0.detail ?? "").localizedCaseInsensitiveContains(searchText) || $0.triggerDescription.localizedCaseInsensitiveContains(searchText) }
    }
}
