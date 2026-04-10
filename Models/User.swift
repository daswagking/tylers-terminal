//
//  User.swift
//  TYLER'S TERMINAL
//
//  User model with ISO8601 date decoding
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case email
        case isAdmin = "is_admin"
        case isVerified = "is_verified"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        email = try container.decode(String.self, forKey: .email)
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        isVerified = try container.decode(Bool.self, forKey: .isVerified)
        
        // Use ISO8601 date decoding
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
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
}

// MARK: - User Profile Extension
extension User {
    var displayName: String {
        username.uppercased()
    }
    
    var formattedJoinDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }
}
