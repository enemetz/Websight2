//
//  CurrencyService.swift
//  websight
//
//  Created by Evan Nemetz on 9/29/26.
//

import Foundation
struct CurrencyService {
    private let baseURL = URL(string: "https://api.frankfurter.dev/v2")!
    
    func getCurrencies() async throws -> [Currencies] {
        try await get("currencies")
    }
    
    func getRates(base: String) async throws -> [ExchangeRate] {
        try await get("rates", query: [URLQueryItem(name: "base", value: base)])
    }
    
    func getRate(from: String, to: String) async throws -> ExchangeRate? {
            let rates: [ExchangeRate] = try await get("rates", query: [
                URLQueryItem(name: "base", value: from),
                URLQueryItem(name: "quotes", value: to)
            ])
            return rates.first
        }
    
    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: path), resolvingAgainstBaseURL: false)
        
        if !query.isEmpty {
            components?.queryItems = query
        }
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
}
