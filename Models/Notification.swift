//
//  Notification.swift
//  TYLER'S TERMINAL
//

import Foundation

struct AppNotification: Identifiable, Codable, Equatable {
    let id: String
    let userId: String
    let type: NotificationType
    let title: String
    let body: String
    var isRead: Bool  // Changed from let to var
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case body
        case isRead = "is_read"
        case createdAt = "created_at"
    }
    
    enum NotificationType: String, Codable {
        case newPost = "new_post"
        case newComment = "new_comment"
        case reaction = "reaction"
        case mention = "mention"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .newPost: return "NEW POST"
            case .newComment: return "COMMENT"
            case .reaction: return "REACTION"
            case .mention: return "MENTION"
            case .system: return "SYSTEM"
            }
        }
        
        var color: String {
            switch self {
            case .newPost: return "#FF6B00"
            case .newComment: return "#00D4AA"
            case .reaction: return "#FF3B30"
            case .mention: return "#007AFF"
            case .system: return "#888888"
            }
        }
        
        var icon: String {
            switch self {
            case .newPost: return "doc.text"
            case .newComment: return "bubble.left"
            case .reaction: return "flame"
            case .mention: return "at"
            case .system: return "gear"
            }
        }
    }
    
    var formattedTimestamp: String {
        return createdAt.timeAgoDisplay
    }
    
    var timeAgo: String {
        return createdAt.timeAgoDisplay
    }
    
    var message: String {
        return body
    }
}
