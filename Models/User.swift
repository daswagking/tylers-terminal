//
//  User.swift
//  TYLER'S TERMINAL
//

import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    let username: String
    let createdAt: Date
    let isAdmin: Bool
    let terminalId: String
    var pushNotificationsEnabled: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case createdAt = "created_at"
        case isAdmin = "is_admin"
        case terminalId = "terminal_id"
        case pushNotificationsEnabled = "push_notifications_enabled"
    }
    
    init(
        id: String,
        username: String,
        createdAt: Date = Date(),
        isAdmin: Bool = false,
        terminalId: String? = nil,
        pushNotificationsEnabled: Bool = true
    ) {
        self.id = id
        self.username = username
        self.createdAt = createdAt
        self.isAdmin = isAdmin
        self.terminalId = terminalId ?? User.generateTerminalId()
        self.pushNotificationsEnabled = pushNotificationsEnabled
    }
    
    static func generateTerminalId() -> String {
        let hexChars = "0123456789ABCDEF"
        var hex = "TT-"
        for _ in 0..<8 {
            hex.append(hexChars.randomElement()!)
        }
        hex.append("-")
        for _ in 0..<4 {
            hex.append(hexChars.randomElement()!)
        }
        return hex
    }
    
    var displayName: String {
        return username.uppercased()
    }
    
    var displayTerminalId: String {
        return terminalId
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: createdAt)
    }
}

enum AuthState: Equatable {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case error(String)
}
