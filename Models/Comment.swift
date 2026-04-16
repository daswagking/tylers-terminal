//
//  Comment.swift
//  TYLER'S TERMINAL
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
        authorUsername = try container.decodeIfPresent(String.self, forKey: .authorUsername) ?? "anonymous"
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""

        createdAt = Self.decodeDate(from: container, key: .createdAt) ?? Date()
        updatedAt = Self.decodeDate(from: container, key: .updatedAt) ?? Date()
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
