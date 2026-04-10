//
//  Comment.swift
//  TYLER'S TERMINAL
//
//  Comment model with ISO8601 date decoding
//

import Foundation

struct Comment: Identifiable, Codable {
    let id: String
    let postId: String
    let authorId: String?
    let authorUsername: String
    let content: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case authorId = "author_id"
        case authorUsername = "author_username"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        postId = try container.decode(String.self, forKey: .postId)
        authorId = try container.decodeIfPresent(String.self, forKey: .authorId)
        authorUsername = try container.decode(String.self, forKey: .authorUsername)
        content = try container.decode(String.self, forKey: .content)
        
        // Try ISO8601 first, then fall back to other formats
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Decode dates as strings first, then convert
        let createdAtString = try container.decode(String.self, forKey: .createdAt)
        let updatedAtString = try container.decode(String.self, forKey: .updatedAt)
        
        if let createdDate = dateFormatter.date(from: createdAtString) {
            createdAt = createdDate
        } else {
            // Try without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            if let createdDate = dateFormatter.date(from: createdAtString) {
                createdAt = createdDate
            } else {
                throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Invalid date format: \(createdAtString)")
            }
        }
        
        if let updatedDate = dateFormatter.date(from: updatedAtString) {
            updatedAt = updatedDate
        } else {
            // Try without fractional seconds
            dateFormatter.formatOptions = [.withInternetDateTime]
            if let updatedDate = dateFormatter.date(from: updatedAtString) {
                updatedAt = updatedDate
            } else {
                throw DecodingError.dataCorruptedError(forKey: .updatedAt, in: container, debugDescription: "Invalid date format: \(updatedAtString)")
            }
        }
    }
    
    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
