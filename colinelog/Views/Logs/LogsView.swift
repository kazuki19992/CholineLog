import SwiftUI
import SwiftData
import Combine

struct LogsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.editMode) private var editMode
    @StateObject private var vm = LogsViewModel()
    @State private var showAddSheet = false
    @State private var editingLog: ColinLog? = nil
    @Query(sort: [SortDescriptor(\ColinLog.createdAt, order: .reverse)]) private var logs: [ColinLog]

    var body: some View {
        NavigationStack {
            List {
                if filteredLogs.isEmpty { Section { Text("まだコリンログがありません").foregroundStyle(.secondary) } }
                ForEach(filteredLogs) { log in
                    NavigationLink { LogDetailView(log: log, editingLog: $editingLog) } label: { ColinLogRow(log: log) }
                }
                .onDelete(perform: deleteLogs)
            }
            .searchable(text: $vm.searchText, placement: .navigationBarDrawer, prompt: "検索")
            .listStyle(.plain)
            .navigationTitle("コリンログ")
            .toolbar { toolbar }
            .sheet(isPresented: $showAddSheet) { AddColinLogView() }
            .sheet(item: $editingLog) { log in EditColinLogView(log: log) }
        }
    }

    private var filteredLogs: [ColinLog] { vm.filtered(logs) }

    private func deleteLogs(offsets: IndexSet) { withAnimation { offsets.forEach { modelContext.delete(filteredLogs[$0]) } } }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) { // 明示指定
            Button(action: { showAddSheet = true }) { Label("追加", systemImage: "plus") }
        }
    }
}
