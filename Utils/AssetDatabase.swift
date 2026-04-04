//
//  AssetDatabase.swift
//  TYLER'S TERMINAL
//

import Foundation

struct AssetDatabase {
    struct Asset {
        let ticker: String
        let category: AssetRequest.AssetCategory
    }
    
    static let allAssets: [Asset] = [
        Asset(ticker: "AAPL", category: .stock),
        Asset(ticker: "GOOGL", category: .stock),
        Asset(ticker: "MSFT", category: .stock),
        Asset(ticker: "AMZN", category: .stock),
        Asset(ticker: "TSLA", category: .stock),
        Asset(ticker: "META", category: .stock),
        Asset(ticker: "NVDA", category: .stock),
        Asset(ticker: "BTC", category: .crypto),
        Asset(ticker: "ETH", category: .crypto),
        Asset(ticker: "SOL", category: .crypto)
    ]
    
    static func search(query: String) -> [(ticker: String, category: AssetRequest.AssetCategory)] {
        let lowercasedQuery = query.lowercased()
        return allAssets
            .filter { $0.ticker.lowercased().contains(lowercasedQuery) }
            .map { (ticker: $0.ticker, category: $0.category) }
    }
    
    static func category(for ticker: String) -> AssetRequest.AssetCategory? {
        return allAssets.first { $0.ticker.uppercased() == ticker.uppercased() }?.category
    }
}
