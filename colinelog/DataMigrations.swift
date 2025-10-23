import Foundation
import SwiftData

/// データ移行管理
enum DataMigrations {
    /// Rash の nil を .noRash へ埋める一度きりのマイグレーション
    /// 戻り値: 更新件数
    static func fixNilRashIfNeeded(context: ModelContext, userDefaults: UserDefaults = .standard) -> Int {
        let flagKey = "migration.rashNilFilled.v1"
        if userDefaults.bool(forKey: flagKey) { return 0 }
        // 一部環境で optional enum を Predicate に含めると
        // "keypath rash not found" 例外が出るため全件 fetch → in-memory filter
        let descriptor = FetchDescriptor<ColinLog>()
        guard let all = try? context.fetch(descriptor) else { return 0 }
        let targets = all.filter { $0.rash == nil }
        if targets.isEmpty { userDefaults.set(true, forKey: flagKey); return 0 }
        for log in targets { log.rash = .noRash }
        do {
            try context.save()
            userDefaults.set(true, forKey: flagKey)
            return targets.count
        } catch {
            print("[Migration] fixNilRashIfNeeded save error: \(error)")
            return 0
        }
    }
}
