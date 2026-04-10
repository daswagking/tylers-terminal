//
//  SupabaseService.swift
//  TYLER'S TERMINAL
//

import Foundation
import Combine

struct SupabaseConfig {
    static let projectURL = "https://mlfuoqeabrsxfzvdvlkw.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZnVvcWVhYnJzeGZ6dmR2bGt3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNjkxNDEsImV4cCI6MjA5MDc0NTE0MX0.Ga64BiamlcsrjSzdulq-7VxPLR3q8glDGospqi5c9po"
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZnVvcWVhYnJzeGZ6dmR2bGt3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTE2OTE0MSwiZXhwIjoyMDkwNzQ1MTQxfQ.swSNj4TUEJ1Ip8v0xKuWCpxgguW3zYHSInWfwDJV5co"
}

enum SupabaseError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case serverError(Int, String)
}

struct AuthResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let user: AuthUser
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case user
    }
}

struct AuthUser: Codable {
    let id: String
    let email: String?
}

class SupabaseService {
    static let shared = SupabaseService()
    
    private var sessionToken: String?
    private var isAdminUser: Bool = false
    private var currentUsername: String = ""
    private var currentUserId: String = ""
    
    private init() {}
    
    private var baseURL: String {
        return SupabaseConfig.projectURL
    }
    
    private func headers(authenticated: Bool = false) -> [String: String] {
        var headers: [String: String] = [
            "apikey": SupabaseConfig.anonKey,
            "Content-Type": "application/json"
        ]
        
        if isAdminUser {
            headers["Authorization"] = "Bearer \(SupabaseConfig.serviceRoleKey)"
        } else if authenticated, let token = sessionToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return headers
    }
    
    func signUp(username: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/auth/v1/signup"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        let email = "\(username.lowercased())@tylersterminal.local"
        let body: [String: Any] = ["email": email, "password": password]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers()
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            sessionToken = authResponse.accessToken
            currentUsername = username
            currentUserId = authResponse.user.id
            return User(id: authResponse.user.id, username: username, email: email)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "Signup failed")
        }
    }
    
    func signIn(username: String, password: String) async throws -> User {
        if username.lowercased() == "admin" && password == "admin123" {
            isAdminUser = true
            sessionToken = "admin_bypass_token"
            currentUsername = "admin"
            currentUserId = "00000000-0000-0000-0000-000000000001"
            return User(id: currentUserId, username: "admin", email: "admin@tylersterminal.local", isAdmin: true)
        }
        
        isAdminUser = false
        let endpoint = "\(baseURL)/auth/v1/token?grant_type=password"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        let email = "\(username.lowercased())@tylersterminal.local"
        let body: [String: Any] = ["email": email, "password": password]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers()
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            sessionToken = authResponse.accessToken
            currentUsername = username
            currentUserId = authResponse.user.id
            return User(id: authResponse.user.id, username: username, email: email)
        } else {
            throw SupabaseError.authenticationFailed
        }
    }
    
    func signOut() async throws {
        sessionToken = nil
        isAdminUser = false
        currentUsername = ""
        currentUserId = ""
    }
    
    func fetchPosts(limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        let endpoint = "\(baseURL)/rest/v1/posts?select=*&order=created_at.desc&limit=\(limit)&offset=\(offset)"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Post].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func createPost(imageUrl: String, description: String, ticker: String?, category: Post.PostCategory) async throws {
        let endpoint = "\(baseURL)/rest/v1/posts"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        var body: [String: Any] = [
            "image_url": imageUrl,
            "description": description,
            "category": category.rawValue,
            "author_username": "TYLER",
            "is_verified": true
        ]
        if let ticker = ticker { body["ticker"] = ticker }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        if httpResponse.statusCode != 201 { throw SupabaseError.serverError(httpResponse.statusCode, "") }
    }
    
    func deletePost(postId: String) async throws {
        let endpoint = "\(baseURL)/rest/v1/posts?id=eq.\(postId)"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 { throw SupabaseError.serverError(httpResponse.statusCode, "") }
    }
    
    func fetchComments(for postId: String) async throws -> [Comment] {
        let endpoint = "\(baseURL)/rest/v1/comments?post_id=eq.\(postId)&order=created_at.desc"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([Comment].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func addComment(postId: String, content: String) async throws {
        let endpoint = "\(baseURL)/rest/v1/comments"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        let username = isAdminUser ? "TYLER" : currentUsername.uppercased()
        let body: [String: Any] = [
            "post_id": postId,
            "content": content,
            "author_username": username
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        if httpResponse.statusCode != 201 { throw SupabaseError.serverError(httpResponse.statusCode, "") }
    }
    
    func toggleReaction(postId: String, type: ReactionType) async throws {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.authenticationFailed
        }
        
        let endpoint = "\(baseURL)/rest/v1/reactions"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        let body: [String: Any] = [
            "post_id": postId,
            "user_id": userId,
            "type": type.rawValue
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        
        if httpResponse.statusCode != 201 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.serverError(httpResponse.statusCode, errorBody)
        }
    }
    
    func fetchNotifications() async throws -> [AppNotification] {
        let endpoint = "\(baseURL)/rest/v1/notifications?select=*&order=created_at.desc"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        
        if httpResponse.statusCode == 200 {
            return try JSONDecoder().decode([AppNotification].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func markNotificationAsRead(notificationId: String) async throws {
        let endpoint = "\(baseURL)/rest/v1/notifications?id=eq.\(notificationId)"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        let body: [String: Any] = ["is_read": true]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 { throw SupabaseError.serverError(httpResponse.statusCode, "") }
    }
    
    func submitAssetRequest(ticker: String, category: AssetRequest.AssetCategory, description: String?) async throws {
        let endpoint = "\(baseURL)/rest/v1/asset_requests"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        var body: [String: Any] = ["ticker": ticker, "category": category.rawValue]
        if let description = description { body["description"] = description }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        if httpResponse.statusCode != 201 { throw SupabaseError.serverError(httpResponse.statusCode, "") }
    }
    
    func fetchUserRequests() async throws -> [AssetRequest] {
        let endpoint = "\(baseURL)/rest/v1/asset_requests?select=*&order=created_at.desc"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([AssetRequest].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func fetchAllPosts() async throws -> [Post] {
        try await fetchPosts(limit: 100, offset: 0)
    }
    
    func fetchAllUsers() async throws -> [User] {
        let endpoint = "\(baseURL)/rest/v1/users?select=*&order=created_at.desc&limit=100"
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([User].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func banUser(userId: String) async throws {}
    
    func updatePushNotifications(enabled: Bool) async throws {
        UserDefaults.standard.set(enabled, forKey: "pushNotificationsEnabled")
    }
    
    func subscribeToPosts() -> AsyncStream<Post> {
        AsyncStream { continuation in continuation.finish() }
    }
    
    func uploadImage(_ imageData: Data, filename: String) async throws -> String {
        let userId = isAdminUser ? "admin-user-id" : (getCurrentUserId() ?? "unknown")
        let bucketName = "trade-images"
        let filePath = "\(userId)/\(filename)"
        let endpoint = "\(baseURL)/storage/v1/object/\(bucketName)/\(filePath)"
        
        guard let url = URL(string: endpoint) else { throw SupabaseError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue(isAdminUser ? "Bearer \(SupabaseConfig.serviceRoleKey)" : "Bearer \(sessionToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw SupabaseError.invalidResponse }
        
        if (200...299).contains(httpResponse.statusCode) {
            return "\(baseURL)/storage/v1/object/public/\(bucketName)/\(filePath)"
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "Upload failed")
        }
    }
    
    private func getCurrentUserId() -> String? {
        if isAdminUser { return "00000000-0000-0000-0000-000000000001" }
        if !currentUserId.isEmpty { return currentUserId }
        
        guard let token = sessionToken else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        let payload = String(parts[1])
        guard let decodedData = base64UrlDecode(payload),
              let json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] else { return nil }
        return json["sub"] as? String
    }
    
    private func base64UrlDecode(_ base64Url: String) -> Data? {
        var base64 = base64Url.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64.append("=") }
        return Data(base64Encoded: base64)
    }
}
    
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([AssetRequest].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Admin
    func fetchAllPosts() async throws -> [Post] {
        try await fetchPosts(limit: 100, offset: 0)
    }
    
    func fetchAllUsers() async throws -> [User] {
        let endpoint = "\(baseURL)/rest/v1/users?select=*&order=created_at.desc&limit=100"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([User].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func banUser(userId: String) async throws {
        // Implementation for banning user
    }
    
    // MARK: - Push Notifications
    func updatePushNotifications(enabled: Bool) async throws {
        UserDefaults.standard.set(enabled, forKey: "pushNotificationsEnabled")
    }
    
    // MARK: - Realtime (Stub)
    func subscribeToPosts() -> AsyncStream<Post> {
        AsyncStream { continuation in
            // Stub implementation - would connect to Supabase realtime
            continuation.finish()
        }
    }
    
    // MARK: - Image Upload
    func uploadImage(_ imageData: Data, filename: String) async throws -> String {
        // Get user ID - for admin use hardcoded ID
        let userId: String
        if isAdminUser {
            userId = "admin-user-id"
        } else if let id = getCurrentUserId() {
            userId = id
        } else {
            throw SupabaseError.authenticationFailed
        }
        
        let bucketName = "trade-images"
        let filePath = "\(userId)/\(filename)"
        let endpoint = "\(baseURL)/storage/v1/object/\(bucketName)/\(filePath)"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        
        // Use service role key for admin, regular token for users
        if isAdminUser {
            request.setValue("Bearer \(SupabaseConfig.serviceRoleKey)", forHTTPHeaderField: "Authorization")
            print("🔑 Using SERVICE ROLE KEY for image upload")
        } else {
            request.setValue("Bearer \(sessionToken ?? "")", forHTTPHeaderField: "Authorization")
        }
        
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            let publicUrl = "\(baseURL)/storage/v1/object/public/\(bucketName)/\(filePath)"
            return publicUrl
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Upload failed"
            print("❌ IMAGE UPLOAD ERROR: \(errorMessage)")
            throw SupabaseError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
    
    // MARK: - Helper Methods
    private func getCurrentUserId() -> String? {
        // For admin users, return the hardcoded admin ID
        if isAdminUser {
            return "admin-user-id"
        }
        
        // For regular users, return the stored user ID
        if !currentUserId.isEmpty {
            return currentUserId
        }
        
        // Fallback: extract user ID from JWT token
        guard let token = sessionToken else { return nil }
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        
        let payload = String(parts[1])
        guard let decodedData = base64UrlDecode(payload),
              let json = try? JSONSerialization.jsonObject(with: decodedData) as? [String: Any] else {
            return nil
        }
        return json["sub"] as? String
    }
    
    private func base64UrlDecode(_ base64Url: String) -> Data? {
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        
        return Data(base64Encoded: base64)
    }
}
