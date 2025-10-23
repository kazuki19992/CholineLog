import SwiftUI
import SwiftData
import Combine

struct OverviewView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm = OverviewViewModel()
    @State private var showAddSheet = false
    @State private var editingLog: ColinLog? = nil
    @Query(sort: [SortDescriptor(\ColinLog.createdAt, order: .reverse)]) private var allLogs: [ColinLog]

    private var dayLogs: [ColinLog] { vm.dayLogs(from: allLogs) }

    var body: some View {
        ZStack {
            NavigationStack {
                scrollContent
                    .navigationTitle("概要")
                    .toolbarTitleDisplayMode(.inline)
                    .toolbar { toolbarItems }
                    .sheet(isPresented: $showAddSheet) { AddColinLogView() }
                    .sheet(item: $editingLog) { log in EditColinLogView(log: log) }
            }
            .background(Color.clear)
        }
    }
}

// MARK: - Scroll Content (List -> ScrollView with fixed date navigator)
private extension OverviewView {
    var scrollContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                chartSection
                if dayLogs.isEmpty { emptyState } else { logsSection }
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8) // 余白
        }
        .safeAreaInset(edge: .top) { fixedDateNavigator }
        .gesture(daySwipeGesture)
        .animation(.easeInOut, value: vm.selectedDate)
        .scrollIndicators(.hidden)
    }
    var chartSection: some View {
        SeverityTimeChart(logs: dayLogs, baseDate: vm.selectedDate)
            .frame(height: 220)
            .padding(12)
            .background(cardBackground(radius: 28, tint: .indigo))
            .overlay(alignment: .topTrailing) {
                Text(vm.selectedDate.colinISODate)
                    .font(.caption2.monospacedDigit())
                    .padding(6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(10)
            }
    }
    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 42))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text("まだコリンログがありません")
                .foregroundStyle(.secondary)
            Button {
                showAddSheet = true
            } label: {
                Label("最初のログを追加", systemImage: "plus")
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    var logsSection: some View {
        LazyVStack(spacing: 8) { // 行間少し広げる
            ForEach(dayLogs) { log in
                NavigationLink { LogDetailView(log: log, editingLog: $editingLog) } label: { // 共通詳細ビューへ統一
                    ColinLogRow(log: log)
                        .padding(.vertical, 8) // 旧:4 -> 拡大
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if log.id != dayLogs.last?.id {
                    Divider()
                        .padding(.leading, SeverityBadge.fixedWidth + 12)
                        .padding(.vertical, 4) // 区切りにも余白
                }
            }
        }
    }
}

// MARK: - Fixed Date Navigator
private extension OverviewView {
    var fixedDateNavigator: some View {
        HStack(spacing: 16) {
            Button(action: vm.previousDay) { Image(systemName: "chevron.backward") }
            VStack(spacing: 2) {
                Text(vm.formattedSelectedDate())
                    .font(.headline.monospacedDigit())
                Text(vm.isToday ? "今日" : vm.selectedDate.colinMonthDay)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            Button(action: vm.nextDay) { Image(systemName: "chevron.forward") }
                .disabled(vm.isToday)
                .opacity(vm.isToday ? 0.3 : 1)
        }
        .font(.title3.weight(.semibold))
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 6)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Helpers / Common UI
private extension OverviewView {
    var dateNavigator: some View { EmptyView() } // 未使用
    var dateNavigatorToolbar: some View { EmptyView() } // toolbar principal から排除
    var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                if dx > 70 { vm.previousDay() } else if dx < -70 { vm.nextDay() }
            }
    }
    @ToolbarContentBuilder
    var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) { Button(action: { showAddSheet = true }) { Image(systemName: "plus") } }
    }
    func cardBackground(radius: CGFloat = 24, tint: Color = .accentColor) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(tint.opacity(0.15), lineWidth: 1)
            )
    }
}
