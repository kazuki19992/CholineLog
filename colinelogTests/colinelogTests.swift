//
//  colinelogTests.swift
//  colinelogTests
//
//  Created by 櫛田一樹 on 2025/09/21.
//

import Testing
import Foundation
@testable import colinelog

struct colinelogTests {

    @Test func severityStars() throws {
        let log = ColinLog(severity: .level3, response: .none, sweating: .none)
        #expect(log.severityStars == "★★★☆☆")
    }

    @Test func responseDescriptionOther() throws {
        let log = ColinLog(severity: .level1, response: .other, responseOtherNote: "氷嚢", sweating: .little)
        #expect(log.responseDescription == "氷嚢")
    }

    @Test func responseDescriptionOtherEmptyFallsBack() throws {
        let log = ColinLog(severity: .level2, response: .other, responseOtherNote: "   ", sweating: .moist)
        #expect(log.responseDescription == "その他")
    }

    @Test func importJSONWithRash() async throws {
        let json = """
        [
          {
            "createdAt": "2025-10-04T01:23:45Z",
            "severity": 3,
            "response": "none",
            "trigger": "stressEmotion",
            "sweating": "none",
            "rash": "light",
            "detail": "テスト",
            "kind": "symptom"
          },
          {
            "createdAt": "2025-10-04T02:00:00Z",
            "severity": 1,
            "response": "none",
            "trigger": "stressEmotion",
            "sweating": "none",
            "rash": null,
            "detail": null,
            "kind": "symptom"
          },
          {
            "createdAt": "2025-10-04T03:00:00Z",
            "severity": 2,
            "response": "none",
            "trigger": "stressEmotion",
            "sweating": "none",
            "rash": "unknown",
            "detail": null,
            "kind": "symptom"
          }
        ]
        """.data(using: .utf8)!
        let vm = await ExportViewModel()
        let logs = await vm.importJSONLogs(data: json)
        #expect(logs.count == 3)
        #expect(logs[0].rash == .light)
        #expect(logs[1].rash == nil)
        #expect(logs[2].rash == nil) // unknown は nil にフォールバック
    }
}
