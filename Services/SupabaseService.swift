//
//  SupabaseService.swift
//  TYLER'S TERMINAL
//

import Foundation
import UIKit

struct SupabaseConfig {
    static let projectURL = "https://mlfuoqeabrsxfzvdvlkw.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZnVvcWVhYnJzeGZ6dmR2bGt3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNjkxNDEsImV4cCI6MjA5MDc0NTE0MX0.Ga64BiamlcsrjSzdulq-7VxPLR3q8glDGospqi5c9po"
}

enum SupabaseError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case serverError(Int, String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "INVALID ENDPOINT"
        case .invalidResponse: return "INVALID RESPONSE"
        case .authenticationFailed: return "AUTHENTICATION FAILED"
        case .serverError(_, let msg): return msg
        }
    }
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
    
    private init() {}
    
    private var baseURL: String {
        return SupabaseConfig.projectURL
    }
    
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
    
    // MARK: - Auth
    func signUp(username: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/auth/v1/signup"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let email = "\(username.lowercased())@tylersterminal.local"
        
        let body: [String: Any] = [
            "email": email,
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
        
        if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            sessionToken = authResponse.accessToken
            return User(id: authResponse.user.id, username: username)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "Signup failed")
        }
    }
    
    func signIn(username: String, password: String) async throws -> (user: User, token: String) {
        let endpoint = "\(baseURL)/auth/v1/token?grant_type=password"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let email = "\(username.lowercased())@tylersterminal.local"
        
        let body: [String: Any] = [
            "email": email,
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
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            sessionToken = authResponse.accessToken
            print("[DEBUG] Sign in successful, token set: \(authResponse.accessToken.prefix(20))...")
            return (User(id: authResponse.user.id, username: username), authResponse.accessToken)
        } else {
            throw SupabaseError.authenticationFailed
        }
    }
        
        let email = "\(username.lowercased())@tylersterminal.local"
        
        let body: [String: Any] = [
            "email": email,
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
        
        if httpResponse.statusCode == 200 {
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            sessionToken = authResponse.accessToken
            return User(id: authResponse.user.id, username: username)
        } else {
            throw SupabaseError.authenticationFailed
        }
    }
    
    func signOut() async throws {
        sessionToken = nil
    }
    
    // MARK: - Posts
    func fetchPosts(limit: Int = 20, offset: Int = 0) async throws -> [Post] {
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
            return try JSONDecoder().decode([Post].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func createPost(imageUrl: String, description: String, ticker: String?, category: Post.PostCategory) async throws {
        let endpoint = "\(baseURL)/rest/v1/posts"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        var body: [String: Any] = [
            "image_url": imageUrl,
            "description": description,
            "category": category.rawValue
        ]
        
        if let ticker = ticker {
            body["ticker"] = ticker
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if httpResponse.statusCode != 201 {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func deletePost(postId: String) async throws {
        let endpoint = "\(baseURL)/rest/v1/posts?id=eq.\(postId)"
        
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
        
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Comments
    func fetchComments(for postId: String) async throws -> [Comment] {
        let endpoint = "\(baseURL)/rest/v1/comments?post_id=eq.\(postId)&order=created_at.desc"
        
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
            return try JSONDecoder().decode([Comment].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func addComment(postId: String, content: String) async throws {
        let endpoint = "\(baseURL)/rest/v1/comments"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "post_id": postId,
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
        
        if httpResponse.statusCode != 201 {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Reactions
    func toggleReaction(postId: String, type: ReactionType) async throws {
        let endpoint = "\(baseURL)/rest/v1/reactions"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "post_id": postId,
            "type": type.rawValue
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if httpResponse.statusCode != 201 && httpResponse.statusCode != 200 {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Notifications
    func fetchNotifications() async throws -> [AppNotification] {
        let endpoint = "\(baseURL)/rest/v1/notifications?select=*&order=created_at.desc"
        
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
            return try JSONDecoder().decode([AppNotification].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func markNotificationAsRead(notificationId: String) async throws {
        let endpoint = "\(baseURL)/rest/v1/notifications?id=eq.\(notificationId)"
        
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
        
        if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Asset Requests
    func submitAssetRequest(ticker: String, category: AssetRequest.AssetCategory, description: String?) async throws {
        let endpoint = "\(baseURL)/rest/v1/asset_requests"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        var body: [String: Any] = [
            "ticker": ticker,
            "category": category.rawValue
        ]
        
        if let description = description {
            body["description"] = description
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        
        if httpResponse.statusCode != 201 {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    func fetchUserRequests() async throws -> [AssetRequest] {
        let endpoint = "\(baseURL)/rest/v1/asset_requests?select=*&order=created_at.desc"
        
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
            return try JSONDecoder().decode([AssetRequest].self, from: data)
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - Image Upload
    func uploadImage(_ image: UIImage) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("[DEBUG] Failed to convert image to JPEG")
            throw SupabaseError.invalidResponse
        }
        
        print("[DEBUG] Image size: \(imageData.count) bytes")
        print("[DEBUG] Base URL: \(baseURL)")
        
        let fileName = "\(UUID().uuidString).jpg"
        
        // Try with URL-encoded space
        let bucketName = "TRADE%20IMAGES"
        let endpoint = "\(baseURL)/storage/v1/object/\(bucketName)/\(fileName)"
        
        print("[DEBUG] Upload endpoint: \(endpoint)")
        
        guard let url = URL(string: endpoint) else {
            print("[DEBUG] Invalid URL")
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = headers(authenticated: true)
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        print("[DEBUG] Headers: \(headers(authenticated: true))")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("[DEBUG] No HTTP response")
                throw SupabaseError.invalidResponse
            }
            
            print("[DEBUG] Status code: \(httpResponse.statusCode)")
            
            if let body = String(data: data, encoding: .utf8) {
                print("[DEBUG] Response body: \(body)")
            }
            
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 {
                let publicUrl = "\(baseURL)/storage/v1/object/public/\(bucketName)/\(fileName)"
                print("[DEBUG] Success! URL: \(publicUrl)")
                return publicUrl
            } else {
                print("[DEBUG] Upload failed with status: \(httpResponse.statusCode)")
                throw SupabaseError.serverError(httpResponse.statusCode, "Upload failed")
            }
        } catch {
            print("[DEBUG] Network error: \(error)")
            throw error
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
            return try JSONDecoder().decode([User].self, from: data)
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
            continuation.finish()
        }
    }
}
