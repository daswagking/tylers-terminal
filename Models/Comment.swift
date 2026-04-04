//
//  Comment.swift
//  TYLER'S TERMINAL
//

import Foundation

struct Comment: Identifiable, Codable, Equatable {
    let id: String
    let postId: String
    let userId: String
    let content: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case userId = "user_id"
        case content
        case createdAt = "created_at"
    }
    
    var authorUsername: String {
        return "USER"
    }
    
    var formattedTimestamp: String {
        return createdAt.timeAgoDisplay
    }
}
