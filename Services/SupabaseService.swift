//
//  SupabaseService.swift
//  TYLER'S TERMINAL
//
//  Supabase client and API operations
//

import Foundation
import Combine

// MARK: - Supabase Configuration
// NOTE: These values must be provided by the user per STOP AND ASK PROTOCOL
struct SupabaseConfig {
    // STOP: User must provide these credentials before building
    static let projectURL = "https://mlfuoqeabrsxfzvdvlkw.supabase.co" // e.g., "https://yourproject.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZnVvcWVhYnJzeGZ6dmR2bGt3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNjkxNDEsImV4cCI6MjA5MDc0NTE0MX0.Ga64BiamlcsrjSzdulq-7VxPLR3q8glDGospqi5c9po"
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZnVvcWVhYnJzeGZ6dmR2bGt3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTE2OTE0MSwiZXhwIjoyMDkwNzQ1MTQxfQ.swSNj4TUEJ1Ip8v0xKuWCpxgguW3zYHSInWfwDJV5co" // For Edge Functions only
}

// MARK: - Supabase Error
enum SupabaseError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case networkError(Error)
    case decodingError(Error)
    case serverError(Int, String)
    case notFound
    case unauthorized
    case conflict(String)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "INVALID ENDPOINT"
        case .invalidResponse:
            return "INVALID RESPONSE"
        case .authenticationFailed:
            return "AUTHENTICATION FAILED"
        case .networkError(let error):
            return "CONNECTION LOST: \(error.localizedDescription)"
        case .decodingError:
            return "DATA PARSE ERROR"
        case .serverError(let code, let message):
            return "SERVER ERROR [\(code)]: \(message)"
        case .notFound:
            return "RESOURCE NOT FOUND"
        case .unauthorized:
            return "UNAUTHORIZED"
        case .conflict(let message):
            return "CONFLICT: \(message)"
        case .unknown:
            return "UNKNOWN ERROR"
        }
    }
}

// MARK: - Supabase Service
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    @Published var isConnected = false
    @Published var lastError: SupabaseError?
    
    private var sessionToken: String?
    private var refreshToken: String?
    private var currentUserId: String?
    
    private init() {}
    
    // MARK: - Base URL
    private var baseURL: String {
        return SupabaseConfig.projectURL
    }
    
    // MARK: - Headers
    private func headers(authenticated: Bool = false) -> [String: String] {
        var headers: [String: String] = [
            "apikey": SupabaseConfig.anonKey,
            "Content-Type": "application/json"
        ]
        
        if authenticated, let token = sessionToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        
        return headers
    }
    
    // MARK: - Authentication
    
    func signUp(username: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/auth/v1/signup"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "email": "\(username.lowercased())@tylersterminal.app", // Username as email
            "password": password,
            "data": [
                "username": username.lowercased(),
                "display_name": username.uppercased()
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers()
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            sessionToken = authResponse.accessToken
            refreshToken = authResponse.refreshToken
            currentUserId = authResponse.user.id
            
            // Create user profile
            let user = User(
                id: authResponse.user.id,
                username: username.lowercased(),
                pushNotificationsEnabled: true
            )
            try await createUserProfile(user: user)
            return user
            
        case 409:
            throw SupabaseError.conflict("USERNAME ALREADY EXISTS")
        case 422:
            throw SupabaseError.authenticationFailed
        default:
            throw SupabaseError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
    
    func signIn(username: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/auth/v1/token?grant_type=password"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "email": "\(username.lowercased())@tylersterminal.app",
            "password": password
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers()
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            sessionToken = authResponse.accessToken
            refreshToken = authResponse.refreshToken
            currentUserId = authResponse.user.id
            
            // Fetch user profile
            let user = try await fetchUserProfile(userId: authResponse.user.id)
            return user
            
        case 400:
            throw SupabaseError.authenticationFailed
        default:
            throw SupabaseError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
    
    func signOut() async throws {
        let endpoint = "\(baseURL)/auth/v1/logout"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 204 {
            sessionToken = nil
            refreshToken = nil
            currentUserId = nil
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - User Profile
    
    private func createUserProfile(user: User) async throws {
        let endpoint = "\(baseURL)/rest/v1/users"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "id": user.id,
            "username": user.username,
            "terminal_id": user.terminalId,
            "push_notifications_enabled": user.pushNotificationsEnabled
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func fetchUserProfile(userId: String) async throws -> User {
        let endpoint = "\(baseURL)/rest/v1/users?id=eq.\(userId)&select=*"
        
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
            let users = try JSONDecoder().decode([User].self, from: data)
            guard let user = users.first else {
                throw SupabaseError.notFound
            }
            return user
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func updatePushNotifications(enabled: Bool) async throws {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/users?id=eq.\(userId)"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "push_notifications_enabled": enabled
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Posts
    
    func fetchPosts(limit: Int = 50, offset: Int = 0) async throws -> [Post] {
        let endpoint = "\(baseURL)/rest/v1/posts?select=*&order=created_at.desc&limit=\(limit)&offset=\(offset)"
        
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
            let posts = try JSONDecoder().decode([Post].self, from: data)
            return posts
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func subscribeToPosts() -> AsyncStream<Post> {
        return AsyncStream { continuation in
            // Real-time subscription via WebSocket would be implemented here
            // For now, we'll use polling as a fallback
            Task {
                while !Task.isCancelled {
                    do {
                        let posts = try await self.fetchPosts(limit: 1)
                        if let latestPost = posts.first {
                            continuation.yield(latestPost)
                        }
                    } catch {
                        print("Subscription error: \(error)")
                    }
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                }
                continuation.finish()
            }
        }
    }
    
    // MARK: - Reactions
    
    func toggleReaction(postId: UUID, type: ReactionType) async throws {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/rpc/toggle_reaction"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "p_post_id": postId.uuidString,
            "p_user_id": userId,
            "p_reaction_type": type.rawValue
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Comments
    
    func fetchComments(postId: UUID) async throws -> [Comment] {
        let endpoint = "\(baseURL)/rest/v1/comments?post_id=eq.\(postId.uuidString)&order=created_at.asc"
        
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
            let comments = try JSONDecoder().decode([Comment].self, from: data)
            return comments
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func addComment(postId: UUID, content: String) async throws {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/comments"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "post_id": postId.uuidString,
            "author_id": userId,
            "content": content
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Asset Requests
    
    func submitAssetRequest(ticker: String, category: AssetRequest.AssetCategory, description: String?) async throws {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/asset_requests"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "ticker": ticker.uppercased(),
            "category": category.rawValue,
            "description": description ?? NSNull(),
            "requester_id": userId
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func fetchUserRequests() async throws -> [AssetRequest] {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/asset_requests?requester_id=eq.\(userId)&order=created_at.desc"
        
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
            let requests = try JSONDecoder().decode([AssetRequest].self, from: data)
            return requests
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Notifications
    
    func fetchNotifications() async throws -> [AppNotification] {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/notifications?user_id=eq.\(userId)&order=created_at.desc"
        
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
            let notifications = try JSONDecoder().decode([AppNotification].self, from: data)
            return notifications
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func markNotificationAsRead(notificationId: UUID) async throws {
        let endpoint = "\(baseURL)/rest/v1/notifications?id=eq.\(notificationId.uuidString)"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "is_read": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Admin Methods
    
    func createPost(imageUrl: String, description: String, ticker: String?, category: Post.PostCategory) async throws {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        // Verify user is admin
        let user = try await fetchUserProfile(userId: userId)
        guard user.isAdmin else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/posts"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "image_url": imageUrl,
            "description": description,
            "author_id": userId,
            "author_username": user.username,
            "is_verified": true,
            "ticker": ticker ?? NSNull(),
            "category": category.rawValue,
            "fire_count": 0,
            "hundred_count": 0,
            "heart_count": 0,
            "comment_count": 0
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func deletePost(postId: UUID) async throws {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        // Verify user is admin
        let user = try await fetchUserProfile(userId: userId)
        guard user.isAdmin else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/posts?id=eq.\(postId.uuidString)"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func deleteComment(commentId: UUID) async throws {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        // Verify user is admin
        let user = try await fetchUserProfile(userId: userId)
        guard user.isAdmin else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/comments?id=eq.\(commentId.uuidString)"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func fetchAllPosts() async throws -> [Post] {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        // Verify user is admin
        let user = try await fetchUserProfile(userId: userId)
        guard user.isAdmin else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/posts?select=*&order=created_at.desc"
        
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
            let posts = try JSONDecoder().decode([Post].self, from: data)
            return posts
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func fetchAllUsers() async throws -> [User] {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        // Verify user is admin
        let user = try await fetchUserProfile(userId: userId)
        guard user.isAdmin else {
            throw SupabaseError.unauthorized
        }
        
        let endpoint = "\(baseURL)/rest/v1/users?select=*&order=created_at.desc"
        
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
            let users = try JSONDecoder().decode([User].self, from: data)
            return users
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func banUser(userId: String) async throws {
        guard let adminId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
        }
        
        // Verify user is admin
        let admin = try await fetchUserProfile(userId: adminId)
        guard admin.isAdmin else {
            throw SupabaseError.unauthorized
        }
        
        // Prevent banning yourself
        guard userId != adminId else {
            throw SupabaseError.conflict("CANNOT BAN YOURSELF")
        }
        
        // In a real app, you'd add a "banned" column to users table
        // For now, we'll delete the user (or you could disable them)
        let endpoint = "\(baseURL)/auth/v1/admin/users/\(userId)"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = headers(authenticated: true)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserId() -> String? {
        return currentUserId
    }
    
    // MARK: - Image Upload
    
    func uploadImage(_ imageData: Data, filename: String) async throws -> String {
        guard let userId = getCurrentUserId() else {
            throw SupabaseError.unauthorized
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
        request.setValue("Bearer \(sessionToken ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if (200...299).contains(httpResponse.statusCode) {
            // Return the public URL for the uploaded image
            let publicUrl = "\(baseURL)/storage/v1/object/public/\(bucketName)/\(filePath)"
            return publicUrl
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Upload failed"
            throw SupabaseError.serverError(httpResponse.statusCode, errorMessage)
        }
    }
}

// MARK: - Auth Response
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
