//
//  CurrencyStore.swift
//  websight
//
//  Created by Evan Nemetz on 9/29/26.
//

import Foundation
@MainActor
@Observable
final class CurrencyStore {
    var currencies: [Currencies] = []
    var rates: [ExchangeRate] = []
    var error: String?

    private let service = CurrencyService()

    func refresh(base: String = "USD") async {
        do {
            async let c = service.getCurrencies()
            async let r = service.getRates(base: base)
            currencies = try await c
            rates = try await r
            error = nil
        } catch {
            self.error = "Couldn't load data: \(error.localizedDescription)"
        }
    }
}
