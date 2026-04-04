//
//  AssetRequest.swift
//  TYLER'S TERMINAL
//

import Foundation

struct AssetRequest: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let ticker: String
    let category: AssetCategory
    let description: String?
    let status: RequestStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case ticker
        case category
        case description
        case status
        case createdAt = "created_at"
    }
    
    enum AssetCategory: String, Codable, CaseIterable {
        case stock = "stock"
        case stocks = "stocks"
        case crypto = "crypto"
        case forex = "forex"
        case commodity = "commodity"
        case other = "other"
        case custom = "custom"
        
        var displayName: String {
            switch self {
            case .stock, .stocks: return "STOCK"
            case .crypto: return "CRYPTO"
            case .forex: return "FOREX"
            case .commodity: return "COMMODITY"
            case .other: return "OTHER"
            case .custom: return "CUSTOM"
            }
        }
        
        var color: String {
            switch self {
            case .stock, .stocks: return "#00D4AA"
            case .crypto: return "#FF6B00"
            case .forex: return "#007AFF"
            case .commodity: return "#FF9500"
            case .other: return "#888888"
            case .custom: return "#FF9500"
            }
        }
    }
    
    enum RequestStatus: String, Codable {
        case pending = "pending"
        case fulfilled = "fulfilled"
        case rejected = "rejected"
        
        var displayName: String {
            switch self {
            case .pending: return "PENDING"
            case .fulfilled: return "FULFILLED"
            case .rejected: return "REJECTED"
            }
        }
    }
    
    var displayTicker: String {
        return ticker.uppercased()
    }
    
    var formattedTimestamp: String {
        return createdAt.timeAgoDisplay
       
        var timeAgoDisplay: String {
            return createdAt.timeAgoDisplay
        }
    
    }
    var timeAgoDisplay: String {
        return createdAt.timeAgoDisplay
    }
}
