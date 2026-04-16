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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        authorUsername = try container.decodeIfPresent(String.self, forKey: .authorUsername) ?? "anonymous"
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl) ?? ""
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        ticker = try container.decodeIfPresent(String.self, forKey: .ticker)
        category = try container.decodeIfPresent(PostCategory.self, forKey: .category) ?? .trade
        fireCount = try container.decodeIfPresent(Int.self, forKey: .fireCount) ?? 0
        hundredCount = try container.decodeIfPresent(Int.self, forKey: .hundredCount) ?? 0
        heartCount = try container.decodeIfPresent(Int.self, forKey: .heartCount) ?? 0
        commentCount = try container.decodeIfPresent(Int.self, forKey: .commentCount) ?? 0
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        createdAt = Self.decodeDate(from: container, key: .createdAt) ?? Date()
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    enum PostCategory: String, Codable, CaseIterable {
        case trade = "TRADE"
        case analysis = "ANALYSIS"
        case news = "NEWS"
        case question = "QUESTION"

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = PostCategory(rawValue: rawValue.uppercased()) ?? .trade
        }

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

enum ReactionType: String, CaseIterable, Codable {
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
        type = try container.decodeIfPresent(ReactionType.self, forKey: .type) ?? .fire
        createdAt = Self.decodeDate(from: container, key: .createdAt) ?? Date()
    }

    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}
