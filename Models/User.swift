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
    
    // Computed properties for UI
    var displayTerminalId: String {
        // Generate a terminal-style ID like "T-001234"
        let shortId = String(id.prefix(6).uppercased())
        return "T-\(shortId)"
    }
    
    var pushNotificationsEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: "pushNotificationsEnabled_\(id)")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "pushNotificationsEnabled_\(id)")
        }
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
        isAdmin = try container.decode(Bool.self, forKey: .isAdmin)
        isVerified = try container.decode(Bool.self, forKey: .isVerified)
        
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
