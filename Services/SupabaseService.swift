//
//  SupabaseService.swift
//  TYLER'S TERMINAL
//
//  Supabase client and API operations
//

import Foundation
import Combine

// MARK: - Supabase Configuration
struct SupabaseConfig {
    static let projectURL = "https://YOUR_PROJECT_ID.supabase.co"
    static let anonKey = "YOUR_ANON_KEY"
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

// MARK: - Supabase Service
class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    @Published var isConnected = false
    @Published var lastError: SupabaseError?
    
    private var sessionToken: String?
    private var refreshToken: String?
    
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
    
    // MARK: - Authentication
    
    func signUp(username: String, password: String) async throws -> User {
        let endpoint = "\(baseURL)/auth/v1/signup"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let email = "\(username.lowercased())@tylersterminal.local"
        
        let body: [String: Any] = [
            "email": email,
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
            self.refreshToken = authResponse.refreshToken
            
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
        
        switch httpResponse.statusCode {
        case 200...299:
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            sessionToken = authResponse.accessToken
            self.refreshToken = authResponse.refreshToken
            
            let user = User(
                id: authResponse.user.id,
                username: username.lowercased(),
                pushNotificationsEnabled: true
            )
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
            self.refreshToken = nil
        } else {
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
    
    // MARK: - User Profile
    
    func createUserProfile(user: User) async throws {
        let endpoint = "\(baseURL)/rest/v1/users"
        
        guard let url = URL(string: endpoint) else {
            throw SupabaseError.invalidURL
        }
        
        let body: [String: Any] = [
            "id": user.id,
            "username": user.username,
            "is_admin": false,
            "is_verified": false
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
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode([Post].self, from: data)
        default:
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
    // MARK: - Push Notifications
    
    func updatePushNotifications(enabled: Bool) async throws {
        // Store in UserDefaults for now
        UserDefaults.standard.set(enabled, forKey: "pushNotificationsEnabled")
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
        
        switch httpResponse.statusCode {
        case 200:
            return try JSONDecoder().decode([AssetRequest].self, from: data)
        default:
            throw SupabaseError.serverError(httpResponse.statusCode, "")
        }
    }
}
