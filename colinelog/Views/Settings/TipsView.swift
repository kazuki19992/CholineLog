import SwiftUI
import StoreKit

struct TipsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var tipStore = TipStore()
    @State private var showMessage = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("チップ")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("閉じる") { dismiss() } } }
                .task { await tipStore.load() }
                .alert(isPresented: Binding(get: { tipStore.lastMessage != nil && showMessage }, set: { if !$0 { tipStore.lastMessage = nil; showMessage = false } })) {
                    Alert(title: Text("ありがとうございます！！"), message: Text(tipStore.lastMessage ?? ""), dismissButton: .default(Text("OK"), action: { tipStore.lastMessage = nil }))
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if tipStore.isLoading && tipStore.tips.allSatisfy({ $0.product == nil }) {
            ProgressView("読み込み中...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                // セルインセットの影響で左寄りに見える問題回避: ヘッダテキストを独立行にしインセット解除
                VStack(spacing: 4) {
                    Text("コリンログをつかっていただき、ありがとうございます！")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fontWeight(.bold)
                        .padding(.bottom, 2)
                    Text("お気に召したら、ぜひチップを贈ってください。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                    Text("今後の開発の励みになります！")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.vertical, 8)
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .accessibilityHidden(false)
                .accessibilityLabel("チップ案内")

                Section {
                    ForEach(tipStore.tips) { tip in
                        Button {
                            Task { await tipStore.purchase(tip); showMessage = tipStore.lastMessage != nil }
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tip.description)
                                        .font(.body)
                                    Text(tip.displayPrice)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(.pink)
                            }
                            .contentShape(Rectangle())
                        }
                        .disabled(tipStore.isLoading || tip.product == nil)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("購入は任意です。")
                        Text("チップを贈ってもアプリの機能が変わることはありません。ご了承ください。")
                        Text("価格は App Store での地域設定により変動する場合があります。")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                Section("操作") {
                    Button {
                        Task { await tipStore.load() }
                    } label: {
                        Label("製品情報を再取得", systemImage: "arrow.clockwise")
                    }
                    .disabled(tipStore.isLoading)
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

#Preview {
    TipsView()
}
