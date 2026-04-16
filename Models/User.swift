//
//  User.swift
//  TYLER'S TERMINAL
//

import Foundation

struct User: Identifiable, Codable {
    let id: String
    let username: String
    let email: String
    let isAdmin: Bool
    let isVerified: Bool
    let createdAt: Date
    let updatedAt: Date

    var displayTerminalId: String {
        let shortId = String(id.prefix(6).uppercased())
        return "T-\(shortId)"
    }

    var pushNotificationsEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "pushNotificationsEnabled_\(id)") }
        set { UserDefaults.standard.set(newValue, forKey: "pushNotificationsEnabled_\(id)") }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case isAdmin = "is_admin"
        case isVerified = "is_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String, username: String, email: String, isAdmin: Bool = false, isVerified: Bool = false, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.username = username
        self.email = email
        self.isAdmin = isAdmin
        self.isVerified = isVerified
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        isAdmin = try container.decodeIfPresent(Bool.self, forKey: .isAdmin) ?? false
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false

        createdAt = Self.decodeDate(container: container, key: .createdAt) ?? Date()
        updatedAt = Self.decodeDate(container: container, key: .updatedAt) ?? Date()
    }

    private static func decodeDate(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard let dateString = try? container.decodeIfPresent(String.self, forKey: key) else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}

extension User {
    var displayName: String { username.uppercased() }

    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
}
