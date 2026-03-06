//
//  History.swift
//  websight
//
//  Created by Evan Nemetz on 3/5/26.
//

import SwiftData
import Foundation

@Model
class History {
    var text: String
    var type: String
    var timestamp: Date
    
    init(text: String, type: String, timestamp: Date = Date()) {
        self.text = text
        self.type = type
        self.timestamp = timestamp
    }
}
