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
    var isRead: Bool
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

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = NotificationType(rawValue: rawValue) ?? .system
        }

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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        type = try container.decodeIfPresent(NotificationType.self, forKey: .type) ?? .system
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? false
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

    var formattedTimestamp: String { createdAt.timeAgoDisplay }
    var timeAgo: String { createdAt.timeAgoDisplay }
    var message: String { body }
}
