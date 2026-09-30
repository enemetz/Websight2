//
//  Quote.swift
//  websight
//
//  Created by Evan Nemetz on 9/29/26.
//

import Foundation
struct ExchangeRate: Codable {
    let date: String
    let base: String
    let quote: String
    let rate: Double
}
