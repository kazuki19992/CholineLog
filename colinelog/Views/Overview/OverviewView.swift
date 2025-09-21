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
        ZStack { backgroundGradient
            NavigationStack {
                listContent
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

// MARK: - List Content
private extension OverviewView {
    var listContent: some View {
        List {
            // ヘッダー (日付ナビ + グラフ)
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    dateNavigator
                        .padding(.top, 4)
                    SeverityTimeChart(logs: dayLogs, baseDate: vm.selectedDate)
                        .frame(height: 220)
                        .padding(.top, 4)
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .background(Color.clear)
            }
            .listSectionSeparator(.hidden, edges: .all)

            if dayLogs.isEmpty {
                Section {
                    Text("まだコリンログがありません")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                }
                .listRowBackground(Color.clear)
                .listSectionSeparator(.hidden, edges: .all)
            } else {
                Section {
                    ForEach(dayLogs) { log in
                        NavigationLink { DetailView(log: log, editingLog: $editingLog) } label: {
                            ColinLogRow(log: log)
                                .padding(.vertical, 6) // 行間余白
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listSectionSeparator(.hidden)
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .gesture(daySwipeGesture)
        .animation(.easeInOut, value: vm.selectedDate)
        .background(Color.clear)
    }
}

// MARK: - Subviews / Helpers
private extension OverviewView {
    var backgroundGradient: some View {
        LinearGradient(colors: [.blue, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
    }
    var dateNavigator: some View {
        HStack(spacing: 16) { // 余白拡大
            Button(action: vm.previousDay) { Image(systemName: "chevron.left").font(.title3) }
            Text(vm.formattedSelectedDate())
                .font(.headline)
                .frame(maxWidth: .infinity)
            Button(action: vm.nextDay) { Image(systemName: "chevron.right").font(.title3) }
                .disabled(vm.isToday)
                .opacity(vm.isToday ? 0.3 : 1)
        }
        .padding(.horizontal, 4)
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .contentShape(Rectangle())
    }
    var daySwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40, coordinateSpace: .local)
            .onEnded { value in
                let dx = value.translation.width
                if dx > 70 { vm.previousDay() } else if dx < -70 { vm.nextDay() }
            }
    }
    @ToolbarContentBuilder
    var toolbarItems: some ToolbarContent {
        ToolbarItem { Button(action: { showAddSheet = true }) { Label("コリンログを追加", systemImage: "plus") } }
    }
}

// MARK: - Detail View (変更なし)
struct DetailView: View {
    let log: ColinLog
    @Binding var editingLog: ColinLog?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { // 余白拡大
                GroupBox("日時") {
                    HStack(spacing: 8) {
                        Text(log.createdAt.colinISODate)
                        Text(log.createdAt.colinTimeHHmm)
                        Spacer()
                    }
                    .font(.body.monospacedDigit())
                }
                GroupBox("強さ") {
                    VStack(alignment: .leading, spacing: 8) {
                        SeverityBadge(severity: log.severity)
                        SweatLevelInline(sweating: log.sweating)
                    }
                }
                VStack(spacing: 16) {
                    GroupBox("メインの発症原因") { Text(log.triggerDescription) }
                    GroupBox("対応") { Text(log.responseDescription) }
                }
                if let detail = log.detail { GroupBox("詳細") { Text(detail) } }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.clear)
        .navigationTitle("詳細")
        .toolbarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("編集") { editingLog = log } } }
    }
}
