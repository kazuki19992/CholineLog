//
//  Item.swift
//  colinelog
//
//  Created by 櫛田一樹 on 2025/09/21.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
