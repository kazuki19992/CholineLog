import Foundation
import StoreKit
import Combine

@MainActor
final class TipStore: ObservableObject {
    struct Tip: Identifiable, Hashable {
        let id: String
        let amount: Int
        let description: String
        var product: Product? = nil
        var displayPrice: String {
            if let product { return product.displayPrice }
            // フォールバック (税抜/税込は StoreKit 価格取得後で確定するため概算表示)
            return "¥\(amount)"
        }
    }

    @Published private(set) var tips: [Tip] = []
    @Published private(set) var isLoading: Bool = false
    @Published var lastMessage: String? = nil

    private var loaded = false

    init() {
        // App Store Connect 登録済み製品ID (<bundle>.tip.1 ~ <bundle>.tip.5) に合わせる。
        // amount は概算の参考金額 (価格改定しても ID は固定)。
        let base: [(String, Int, String)] = [
            ("1", 100,  "開発者にお茶を買ってあげる"),
            ("2", 300,  "開発者におやつセットを買ってあげる"),
            ("3", 500,  "開発者に牛丼を買ってあげる"),
            ("4", 1000, "開発者にラーメンを買ってあげる"),
            ("5", 3000, "開発者にステーキを買ってあげる")
        ]
        let bundle = Bundle.main.bundleIdentifier ?? "app"
        self.tips = base.map { key, amount, desc in
            Tip(id: bundle + ".tip." + key, amount: amount, description: desc)
        }
    }

    func load() async {
        guard !loaded else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let ids = tips.map { $0.id }
            let products = try await Product.products(for: ids)
            var dict: [String: Product] = [:]
            for p in products { dict[p.id] = p }
            tips = tips.map { tip in
                var t = tip
                t.product = dict[tip.id]
                return t
            }
            loaded = true
        } catch {
            lastMessage = "製品情報取得失敗: \(error.localizedDescription)"
        }
    }

    func purchase(_ tip: Tip) async {
        guard let product = tip.product else {
            lastMessage = "製品情報が未取得です"; return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .unverified:
                    lastMessage = "購入に失敗しました"
                case .verified:
                    lastMessage = "ありがとうございます！ (\(tip.displayPrice))"
                }
            case .userCancelled:
                lastMessage = nil
            case .pending:
                lastMessage = "保留中です"
            @unknown default:
                lastMessage = "不明な結果"
            }
        } catch {
            lastMessage = "購入失敗: \(error.localizedDescription)"
        }
    }
}
