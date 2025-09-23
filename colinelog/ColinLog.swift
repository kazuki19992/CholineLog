// filepath: /Users/kazuki19992/gits/colinelog/colinelog/ColinLog.swift
// コリンログモデル定義
//  Created automatically

import Foundation
import SwiftData

@Model
final class ColinLog {
    enum Severity: Int, CaseIterable, Identifiable, Codable {
        case level1 = 1, level2, level3, level4, level5
        var id: Int { rawValue }
        // 日本語表示ラベル (要件): 1:違和感 2:かゆい 3:チクチク 4:強チク 5:キツい
        var label: String {
            switch self {
            case .level1: return "違和感"
            case .level2: return "かゆい"
            case .level3: return "チクチク"
            case .level4: return "強チク"
            case .level5: return "キツい"
            }
        }
        var short: String { String(rawValue) }
    }

    enum ResponseAction: String, CaseIterable, Identifiable, Codable {
        case none
        case icePack // 保冷剤を当てた
        case shower // 水を浴びた
        case coolSpray // 冷感スプレーを使用した
        case coolPlace // 涼しい場所に避難した / 送風で冷ました
        case antiItch // かゆみ止めを使用した
        case scratched // 掻きむしってしまった
        case other // その他
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "何もしなかった"
            case .icePack: return "保冷剤を当てた"
            case .shower: return "水を浴びた"
            case .coolSpray: return "冷感スプレー"
            case .coolPlace: return "涼しい場所に避難した"
            case .antiItch: return "かゆみ止め"
            case .scratched: return "掻いた"
            case .other: return "その他"
            }
        }
        static var allCases: [ResponseAction] { [.none, .icePack, .coolSpray, .coolPlace, .shower, .antiItch, .scratched, .other] }
    }

    enum SweatingLevel: String, CaseIterable, Identifiable, Codable {
        case none // 無汗
        case moist // しっとり
        case little // 少し
        case much // ダラダラ
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "無汗"
            case .moist: return "しっとり"
            case .little: return "少し"
            case .much: return "ダラダラ"
            }
        }
    }

    enum Trigger: String, CaseIterable, Identifiable, Codable {
        case stressEmotion // 感情の動きがあった
        case exercise // 運動した
        case bath // お風呂に入った
        case highTemp // 気温が高かった
        case afterSweat // 汗をかいた
        case spicyHotIntake // 辛いもの・熱いものを飲食した
        case dontKnow // わからない
        case other // その他
        var id: String { rawValue }
        var label: String {
            switch self {
            case .stressEmotion: return "感情の動きがあった"
            case .exercise: return "運動した"
            case .bath: return "お風呂に入った"
            case .highTemp: return "気温が高かった"
            case .afterSweat: return "汗をかいた"
            case .spicyHotIntake: return "辛いもの・熱いものを飲食した"
            case .dontKnow: return "わからない"
            case .other: return "その他"
            }
        }
    }

    enum Kind: String, CaseIterable, Identifiable, Codable {
        case symptom
        case memo
        var id: String { rawValue }
        var label: String { self == .symptom ? "症状ログ" : "メモ" }
    }

    var createdAt: Date
    var severity: Severity
    var response: ResponseAction
    var responseOtherNote: String?
    var trigger: Trigger
    var triggerOtherNote: String?
    var sweating: SweatingLevel
    var detail: String?
    var kind: Kind

    init(createdAt: Date = Date(), severity: Severity, response: ResponseAction, responseOtherNote: String? = nil, trigger: Trigger = .stressEmotion, triggerOtherNote: String? = nil, sweating: SweatingLevel, detail: String? = nil, kind: Kind = .symptom) {
        self.createdAt = createdAt
        self.severity = severity
        self.response = response
        self.responseOtherNote = responseOtherNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : responseOtherNote
        self.trigger = trigger
        self.triggerOtherNote = triggerOtherNote?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : triggerOtherNote
        self.sweating = sweating
        self.detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true ? nil : detail
        self.kind = kind
    }
}

extension ColinLog {
    var severityStars: String { String(repeating: "★", count: severity.rawValue) + String(repeating: "☆", count: 5 - severity.rawValue) }
    var responseDescription: String {
        switch response {
        case .other: return responseOtherNote?.isEmpty == false ? responseOtherNote! : "その他"
        default: return response.label
        }
    }
    var triggerDescription: String {
        switch trigger {
        case .other: return triggerOtherNote?.isEmpty == false ? triggerOtherNote! : "その他"
        default: return trigger.label
        }
    }
}

extension ColinLog.Trigger {
    var iconSystemName: String {
        switch self {
        case .stressEmotion: return "exclamationmark.triangle"
        case .exercise: return "figure.run"
        case .bath: return "shower"
        case .highTemp: return "thermometer.sun"
        case .afterSweat: return "drop"
        case .spicyHotIntake: return "flame"
        case .dontKnow: return "questionmark.circle"
        case .other: return "ellipsis"
        }
    }
}

extension ColinLog.ResponseAction {
    var iconSystemName: String {
        switch self {
        case .none: return "minus"
        case .icePack: return "snowflake"
        case .shower: return "drop.triangle"
        case .coolSpray: return "wind"
        case .coolPlace: return "fan"
        case .antiItch: return "bandage"
        case .scratched: return "hand.raised"
        case .other: return "ellipsis"
        }
    }
}

extension Date {
    private static let _isoFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "yyyy/MM/dd"
        return df
    }()
    private static let _timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "HH:mm"
        return df
    }()
    private static let _monthDayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        df.dateFormat = "MM/dd"
        return df
    }()

    var colinISODate: String { Date._isoFormatter.string(from: self) }
    var colinTimeHHmm: String { Date._timeFormatter.string(from: self) }
    var colinMonthDay: String { Date._monthDayFormatter.string(from: self) }
}
