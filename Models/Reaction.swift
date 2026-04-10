//
//  Reaction.swift
//  TYLER'S TERMINAL
//
//  Reaction model
//

import Foundation

enum ReactionType: String, Codable, CaseIterable {
    case fire = "FIRE"
    case hundred = "HUNDRED"
    case heart = "HEART"
    
    var emoji: String {
        switch self {
        case .fire: return "🔥"
        case .hundred: return "💯"
        case .heart: return "❤️"
        }
    }
}

struct Reaction: Identifiable, Codable {
    let id: String
    let postId: String
    let userId: String
    let type: ReactionType
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case type
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        userId = try container.decode(String.self, forKey: .userId)
        type = try container.decode(ReactionType.self, forKey: .type)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct UserReactions: Codable {
    let hasFired: Bool
    let hasHundred: Bool
    let hasHeart: Bool
}
