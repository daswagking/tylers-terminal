//
//  Post.swift
//  TYLER'S TERMINAL
//

import Foundation

struct Post: Identifiable, Codable, Equatable {
    let id: String
    let authorUsername: String
    let imageUrl: String
    let description: String
    let ticker: String?
    let category: PostCategory
    let fireCount: Int
    let hundredCount: Int
    let heartCount: Int
    let commentCount: Int
    let createdAt: Date
    let isVerified: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case authorUsername = "author_username"
        case imageUrl = "image_url"
        case description
        case ticker
        case category
        case fireCount = "fire_count"
        case hundredCount = "hundred_count"
        case heartCount = "heart_count"
        case commentCount = "comment_count"
        case createdAt = "created_at"
        case isVerified = "is_verified"
    }
    
    enum PostCategory: String, Codable, CaseIterable {
        case trade = "TRADE"
        case analysis = "ANALYSIS"
        case news = "NEWS"
        case question = "QUESTION"
        
        var displayName: String {
            switch self {
            case .trade: return "TRADE"
            case .analysis: return "ANALYSIS"
            case .news: return "NEWS"
            case .question: return "QUESTION"
            }
        }
        
        var color: String {
            switch self {
            case .trade: return "#FF6B00"
            case .analysis: return "#00D4AA"
            case .news: return "#007AFF"
            case .question: return "#FF9500"
            }
        }
    }
    
    var formattedTimestamp: String {
        return createdAt.timeAgoDisplay
    }
    
    var userReactions: UserReactions? {
        return nil
    }
}

struct UserReactions: Codable {
    let hasFired: Bool
    let hasHundred: Bool
    let hasHeart: Bool
}

enum ReactionType: String, CaseIterable {
    case fire = "fire"
    case hundred = "hundred"
    case heart = "heart"
    
    var emoji: String {
        switch self {
        case .fire: return "🔥"
        case .hundred: return "💯"
        case .heart: return "❤️"
        }
    }
}
