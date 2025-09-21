//
//  colinelogTests.swift
//  colinelogTests
//
//  Created by 櫛田一樹 on 2025/09/21.
//

import Testing
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
}
