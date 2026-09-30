//
//  Currencies.swift
//  websight
//
//  Created by Evan Nemetz on 9/29/26.
//

import Foundation
struct Currencies: Codable, Identifiable {
    let isoCode: String
    
    var id: String { isoCode }

    enum CodingKeys: String, CodingKey {
        case isoCode = "iso_code"
    }
}
