import Foundation
import SwiftUI
import Combine

@MainActor
final class OverviewViewModel: ObservableObject {
    @Published var selectedDate: Date
    private let calendar = Calendar.current
    init(today: Date = Date()) {
        self.selectedDate = calendar.startOfDay(for: today)
    }
    var isToday: Bool { calendar.isDate(selectedDate, inSameDayAs: Date()) }
    func previousDay() { if let d = calendar.date(byAdding: .day, value: -1, to: selectedDate) { selectedDate = d } }
    func nextDay() { guard !isToday else { return }; if let d = calendar.date(byAdding: .day, value: 1, to: selectedDate), d <= Date() { selectedDate = d } }
    func dayLogs(from logs: [ColinLog]) -> [ColinLog] { logs.filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) } }
    func formattedSelectedDate(locale: Locale = Locale(identifier: "ja_JP")) -> String {
        let df = DateFormatter(); df.locale = locale; df.dateFormat = "yyyy/MM/dd (E)"; return df.string(from: selectedDate)
    }
}
