import Foundation

// MARK: - Supabase Configuration
struct SupabaseConfig {
    static let projectURL = "https://mlfuoqeabrsxfzvdvlkw.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZnVvcWVhYnJzeGZ6dmR2bGt3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNjkxNDEsImV4cCI6MjA5MDc0NTE0MX0.Ga64BiamlcsrjSzdulq-7VxPLR3q8glDGospqi5c9po"
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZnVvcWVhYnJzeGZ6dmR2bGt3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTE2OTE0MSwiZXhwIjoyMDkwNzQ1MTQxfQ.swSNj4TUEJ1Ip8v0xKuWCpxgguW3zYHSInWfwDJV5co"
}

// MARK: - Supabase Error
enum SupabaseError: Error, LocalizedError {
    case networkError
    case decodingError
    case serverError(String)
    case notFound
    case unauthorized
    case unknown
    case invalidCredentials
    
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network connection failed"
        case .decodingError:
            return "Failed to parse data"
        case .serverError(let message):
            return message
        case .notFound:
            return "Resource not found"
        case .unauthorized:
            return "Unauthorized access"
        case .unknown:
            return "Unknown error occurred"
        case .invalidCredentials:
            return "Invalid username or password"
        }
    }
}

// MARK: - Supabase Service
class SupabaseService {
    static let shared = SupabaseService()
    
    private let baseURL: String
    private let anonKey: String
    private let serviceRoleKey: String
    private var authToken: String?
    
    // Admin user ID - using valid UUID format for database compatibility
    private let adminUserId = "00000000-0000-0000-0000-000000000001"
    
    private init() {
        print("🔧 [SupabaseService] Initializing...")
        self.baseURL = SupabaseConfig.projectURL
        self.anonKey = SupabaseConfig.anonKey
        self.serviceRoleKey = SupabaseConfig.serviceRoleKey
        print("✅ [SupabaseService] Initialized with baseURL: \(baseURL)")
    }
    
    // MARK: - Authentication
    
    func setAuthToken(_ token: String) {
        print("🔐 [SupabaseService] Setting auth token")
        self.authToken = token
    }
    
    func clearAuthToken() {
        print("🚫 [SupabaseService] Clearing auth token")
        self.authToken = nil
    }
    
    private func getHeaders(useServiceRole: Bool = false) -> [String: String] {
        print("📋 [SupabaseService] Building headers, useServiceRole: \(useServiceRole)")
        var headers = [
            "Content-Type": "application/json",
            "apikey": useServiceRole ? serviceRoleKey : anonKey
        ]
        
        if useServiceRole {
            print("🔑 [SupabaseService] Using service role key")
            headers["Authorization"] = "Bearer \(serviceRoleKey)"
        } else if let token = authToken {
            print("🔑 [SupabaseService] Using auth token")
            headers["Authorization"] = "Bearer \(token)"
        } else {
            print("🔑 [SupabaseService] Using anon key for Authorization")
            headers["Authorization"] = "Bearer \(anonKey)"
        }
        
        return headers
    }
    
    // MARK: - Sign In / Sign Up
    
    func signIn(username: String, password: String) async throws -> User {
        print("🔐 [SupabaseService] Signing in user: \(username)")
        
        // For now, use a simple lookup by username
        // In production, you'd use Supabase Auth with proper password hashing
        let url = URL(string: "\(baseURL)/rest/v1/profiles?username=eq.\(username)&select=*")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.invalidCredentials
            }
        }
        
        do {
            let users = try JSONDecoder().decode([User].self, from: data)
            guard let user = users.first else {
                print("❌ [SupabaseService] User not found")
                throw SupabaseError.invalidCredentials
            }
            print("✅ [SupabaseService] User signed in: \(user.username)")
            return user
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    func signUp(username: String, password: String) async throws -> User {
        print("🔐 [SupabaseService] Signing up user: \(username)")
        
        // Check if username already exists
        let checkUrl = URL(string: "\(baseURL)/rest/v1/profiles?username=eq.\(username)&select=id")!
        var checkRequest = URLRequest(url: checkUrl)
        checkRequest.httpMethod = "GET"
        checkRequest.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        let (checkData, checkResponse) = try await URLSession.shared.data(for: checkRequest)
        
        if let httpResponse = checkResponse as? HTTPURLResponse, httpResponse.statusCode == 200 {
            if let existingUsers = try? JSONDecoder().decode([[String: String]].self, from: checkData),
               !existingUsers.isEmpty {
                print("❌ [SupabaseService] Username already exists")
                throw SupabaseError.serverError("Username already exists")
            }
        }
        
        // Create new user
        let userId = UUID().uuidString
        let email = "\(username.lowercased())@tylersterminal.local"
        
        let url = URL(string: "\(baseURL)/rest/v1/profiles")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let userData: [String: Any] = [
            "id": userId,
            "username": username,
            "email": email,
            "is_admin": false,
            "is_verified": false,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: userData)
        
        print("📤 [SupabaseService] Sending POST request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                let errorString = String(data: data, encoding: .utf8) ?? "nil"
                print("❌ [SupabaseService] Error response: \(errorString)")
                throw SupabaseError.serverError("Failed to create user: \(errorString)")
            }
        }
        
        // Return the created user
        let user = User(id: userId, username: username, email: email)
        print("✅ [SupabaseService] User signed up: \(user.username)")
        return user
    }
    
    // MARK: - Posts
    
    func fetchPosts(limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        print("📥 [SupabaseService] Fetching posts... limit: \(limit), offset: \(offset)")
        let url = URL(string: "\(baseURL)/rest/v1/posts?select=*&order=created_at.desc&limit=\(limit)&offset=\(offset)")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to fetch posts")
            }
        }
        
        do {
            let posts = try JSONDecoder().decode([Post].self, from: data)
            print("✅ [SupabaseService] Fetched \(posts.count) posts")
            return posts
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    func fetchAllPosts() async throws -> [Post] {
        print("📥 [SupabaseService] Fetching all posts...")
        let url = URL(string: "\(baseURL)/rest/v1/posts?select=*&order=created_at.desc")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to fetch posts")
            }
        }
        
        do {
            let posts = try JSONDecoder().decode([Post].self, from: data)
            print("✅ [SupabaseService] Fetched \(posts.count) posts")
            return posts
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    func fetchPost(id: String) async throws -> Post {
        print("📥 [SupabaseService] Fetching post with id: \(id)")
        let url = URL(string: "\(baseURL)/rest/v1/posts?id=eq.\(id)&select=*")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to fetch post")
            }
        }
        
        let posts = try JSONDecoder().decode([Post].self, from: data)
        guard let post = posts.first else {
            print("❌ [SupabaseService] Post not found")
            throw SupabaseError.notFound
        }
        print("✅ [SupabaseService] Fetched post by: \(post.authorUsername)")
        return post
    }
    
    func createPost(description: String, imageUrl: String, ticker: String? = nil, category: Post.PostCategory = .trade, authorUsername: String) async throws -> Post {
        print("📝 [SupabaseService] Creating post...")
        print("📝 [SupabaseService] Description: \(description)")
        print("📝 [SupabaseService] Image URL: \(imageUrl)")
        print("📝 [SupabaseService] Ticker: \(ticker ?? "nil")")
        print("📝 [SupabaseService] Category: \(category)")
        print("📝 [SupabaseService] Author: \(authorUsername)")
        
        let url = URL(string: "\(baseURL)/rest/v1/posts")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let postData: [String: Any] = [
            "author_username": authorUsername,
            "image_url": imageUrl,
            "description": description,
            "ticker": ticker ?? "",
            "category": category.rawValue,
            "fire_count": 0,
            "hundred_count": 0,
            "heart_count": 0,
            "comment_count": 0,
            "is_verified": false,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: postData)
        
        print("📤 [SupabaseService] Sending POST request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to create post")
            }
        }
        
        let posts = try JSONDecoder().decode([Post].self, from: data)
        guard let post = posts.first else {
            print("❌ [SupabaseService] No post returned")
            throw SupabaseError.unknown
        }
        print("✅ [SupabaseService] Created post with id: \(post.id)")
        return post
    }
    
    func deletePost(postId: String) async throws {
        print("🗑️ [SupabaseService] Deleting post: \(postId)")
        let url = URL(string: "\(baseURL)/rest/v1/posts?id=eq.\(postId)")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending DELETE request...")
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
                print("❌ [SupabaseService] Delete failed")
                throw SupabaseError.serverError("Failed to delete post")
            }
        }
        print("✅ [SupabaseService] Post deleted successfully")
    }
    
    // MARK: - Comments
    
    func fetchComments(for postId: String) async throws -> [Comment] {
        print("📥 [SupabaseService] Fetching comments for post: \(postId)")
        let url = URL(string: "\(baseURL)/rest/v1/comments?post_id=eq.\(postId)&select=*&order=created_at.desc")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to fetch comments")
            }
        }
        
        do {
            let comments = try JSONDecoder().decode([Comment].self, from: data)
            print("✅ [SupabaseService] Fetched \(comments.count) comments")
            return comments
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    func addComment(postId: String, content: String) async throws {
        print("💬 [SupabaseService] Creating comment...")
        print("💬 [SupabaseService] Post ID: \(postId)")
        print("💬 [SupabaseService] Content: \(content)")
        
        let url = URL(string: "\(baseURL)/rest/v1/comments")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        // Get current user info - for now using admin
        let commentData: [String: Any] = [
            "post_id": postId,
            "author_id": adminUserId,
            "author_username": "admin",
            "content": content,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: commentData)
        
        print("📤 [SupabaseService] Sending POST request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to create comment")
            }
        }
        
        print("✅ [SupabaseService] Comment created successfully")
    }
    
    func deleteComment(id: String) async throws {
        print("🗑️ [SupabaseService] Deleting comment: \(id)")
        let url = URL(string: "\(baseURL)/rest/v1/comments?id=eq.\(id)")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending DELETE request...")
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
                print("❌ [SupabaseService] Delete failed")
                throw SupabaseError.serverError("Failed to delete comment")
            }
        }
        print("✅ [SupabaseService] Comment deleted successfully")
    }
    
    // MARK: - Reactions
    
    func fetchReactions(for postId: String) async throws -> [Reaction] {
        print("❤️ [SupabaseService] Fetching reactions for post: \(postId)")
        let url = URL(string: "\(baseURL)/rest/v1/reactions?post_id=eq.\(postId)&select=*")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to fetch reactions")
            }
        }
        
        do {
            let reactions = try JSONDecoder().decode([Reaction].self, from: data)
            print("✅ [SupabaseService] Fetched \(reactions.count) reactions")
            for reaction in reactions {
                print("   - \(reaction.type.emoji) by \(reaction.userId)")
            }
            return reactions
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    func toggleReaction(postId: String, type: ReactionType) async throws {
        print("🔄 [SupabaseService] Toggling reaction...")
        print("🔄 [SupabaseService] Post ID: \(postId)")
        print("🔄 [SupabaseService] Reaction Type: \(type)")
        print("🔄 [SupabaseService] User ID: \(adminUserId)")
        
        // First, check if user already has this reaction
        print("🔍 [SupabaseService] Checking existing reactions...")
        let existingReactions = try await fetchReactions(for: postId)
        print("🔍 [SupabaseService] Found \(existingReactions.count) total reactions")
        
        let userReaction = existingReactions.first { $0.userId == adminUserId && $0.type == type }
        
        if let existingReaction = userReaction {
            // User already has this reaction, remove it
            print("🗑️ [SupabaseService] Found existing reaction, removing: \(existingReaction.id)")
            try await deleteReaction(id: existingReaction.id)
            // Decrement count on post
            try await updateReactionCount(postId: postId, type: type, increment: false)
            print("✅ [SupabaseService] Reaction removed")
        } else {
            // User doesn't have this reaction, add it
            print("➕ [SupabaseService] No existing reaction found, adding new reaction")
            try await addReaction(postId: postId, type: type)
            // Increment count on post
            try await updateReactionCount(postId: postId, type: type, increment: true)
            print("✅ [SupabaseService] Reaction added")
        }
    }
    
    private func addReaction(postId: String, type: ReactionType) async throws {
        print("➕ [SupabaseService] Adding reaction...")
        print("➕ [SupabaseService] Post ID: \(postId)")
        print("➕ [SupabaseService] Type: \(type)")
        print("➕ [SupabaseService] User ID: \(adminUserId)")
        
        let url = URL(string: "\(baseURL)/rest/v1/reactions")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let reactionData: [String: Any] = [
            "post_id": postId,
            "user_id": adminUserId,
            "type": type.rawValue,
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: reactionData)
        
        print("📤 [SupabaseService] Sending POST request...")
        print("📤 [SupabaseService] Request body: \(reactionData)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                let errorString = String(data: data, encoding: .utf8) ?? "nil"
                print("❌ [SupabaseService] Error response: \(errorString)")
                throw SupabaseError.serverError("Failed to add reaction: \(errorString)")
            }
        }
        
        print("✅ [SupabaseService] Reaction added successfully")
    }
    
    private func deleteReaction(id: String) async throws {
        print("🗑️ [SupabaseService] Deleting reaction: \(id)")
        let url = URL(string: "\(baseURL)/rest/v1/reactions?id=eq.\(id)")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending DELETE request...")
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
                print("❌ [SupabaseService] Delete failed")
                throw SupabaseError.serverError("Failed to delete reaction")
            }
        }
        print("✅ [SupabaseService] Reaction deleted successfully")
    }
    
    private func updateReactionCount(postId: String, type: ReactionType, increment: Bool) async throws {
        print("📊 [SupabaseService] Updating reaction count for post: \(postId), type: \(type), increment: \(increment)")
        
        // First fetch the current post to get current counts
        let post = try await fetchPost(id: postId)
        
        var updates: [String: Any] = [:]
        
        switch type {
        case .fire:
            updates["fire_count"] = max(0, post.fireCount + (increment ? 1 : -1))
        case .hundred:
            updates["hundred_count"] = max(0, post.hundredCount + (increment ? 1 : -1))
        case .heart:
            updates["heart_count"] = max(0, post.heartCount + (increment ? 1 : -1))
        }
        
        let url = URL(string: "\(baseURL)/rest/v1/posts?id=eq.\(postId)")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: updates)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
                print("❌ [SupabaseService] Failed to update reaction count")
                throw SupabaseError.serverError("Failed to update reaction count")
            }
        }
        
        print("✅ [SupabaseService] Reaction count updated")
    }
    
    // MARK: - Asset Requests
    
    func submitAssetRequest(ticker: String, category: AssetRequest.AssetCategory, description: String?) async throws {
        print("📊 [SupabaseService] Submitting asset request...")
        print("📊 [SupabaseService] Ticker: \(ticker)")
        print("📊 [SupabaseService] Category: \(category)")
        print("📊 [SupabaseService] Description: \(description ?? "nil")")
        
        let url = URL(string: "\(baseURL)/rest/v1/asset_requests")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let requestData: [String: Any] = [
            "user_id": adminUserId,
            "ticker": ticker.uppercased(),
            "category": category.rawValue,
            "description": description ?? "",
            "status": "pending",
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)
        
        print("📤 [SupabaseService] Sending POST request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                let errorString = String(data: data, encoding: .utf8) ?? "nil"
                print("❌ [SupabaseService] Error response: \(errorString)")
                throw SupabaseError.serverError("Failed to submit asset request: \(errorString)")
            }
        }
        
        print("✅ [SupabaseService] Asset request submitted successfully")
    }
    
    func fetchUserRequests() async throws -> [AssetRequest] {
        print("📊 [SupabaseService] Fetching user requests...")
        let url = URL(string: "\(baseURL)/rest/v1/asset_requests?user_id=eq.\(adminUserId)&select=*&order=created_at.desc")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to fetch user requests")
            }
        }
        
        do {
            let requests = try JSONDecoder().decode([AssetRequest].self, from: data)
            print("✅ [SupabaseService] Fetched \(requests.count) user requests")
            return requests
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    // MARK: - Notifications
    
    func fetchNotifications() async throws -> [AppNotification] {
        print("🔔 [SupabaseService] Fetching notifications...")
        let url = URL(string: "\(baseURL)/rest/v1/notifications?user_id=eq.\(adminUserId)&select=*&order=created_at.desc")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to fetch notifications")
            }
        }
        
        do {
            let notifications = try JSONDecoder().decode([AppNotification].self, from: data)
            print("✅ [SupabaseService] Fetched \(notifications.count) notifications")
            return notifications
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    func markNotificationAsRead(notificationId: String) async throws {
        print("🔔 [SupabaseService] Marking notification as read: \(notificationId)")
        let url = URL(string: "\(baseURL)/rest/v1/notifications?id=eq.\(notificationId)")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let updateData: [String: Any] = [
            "is_read": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        print("📤 [SupabaseService] Sending PATCH request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
                let errorString = String(data: data, encoding: .utf8) ?? "nil"
                print("❌ [SupabaseService] Error response: \(errorString)")
                throw SupabaseError.serverError("Failed to mark notification as read: \(errorString)")
            }
        }
        
        print("✅ [SupabaseService] Notification marked as read")
    }
    
    // MARK: - Image Upload
    
    func uploadImage(data: Data, filename: String, contentType: String = "image/jpeg") async throws -> String {
        print("📤 [SupabaseService] Uploading image...")
        print("📤 [SupabaseService] Filename: \(filename)")
        print("📤 [SupabaseService] Content-Type: \(contentType)")
        print("📤 [SupabaseService] Data size: \(data.count) bytes")
        
        let bucketName = "post-images"
        let url = URL(string: "\(baseURL)/storage/v1/object/\(bucketName)/\(filename)")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceRoleKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data
        
        print("📤 [SupabaseService] Sending upload request...")
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
                print("❌ [SupabaseService] Upload failed")
                throw SupabaseError.serverError("Failed to upload image")
            }
        }
        
        let imageUrl = "\(baseURL)/storage/v1/object/public/\(bucketName)/\(filename)"
        print("✅ [SupabaseService] Image uploaded: \(imageUrl)")
        return imageUrl
    }
    
    // MARK: - User Profile
    
    func fetchUser(userId: String) async throws -> User {
        print("👤 [SupabaseService] Fetching user: \(userId)")
        let url = URL(string: "\(baseURL)/rest/v1/profiles?id=eq.\(userId)&select=*")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to fetch user")
            }
        }
        
        do {
            let users = try JSONDecoder().decode([User].self, from: data)
            guard let user = users.first else {
                print("❌ [SupabaseService] User not found")
                throw SupabaseError.notFound
            }
            print("✅ [SupabaseService] Fetched user: \(user.username)")
            return user
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    func createUser(id: String, username: String, email: String) async throws -> User {
        print("👤 [SupabaseService] Creating user...")
        print("👤 [SupabaseService] ID: \(id)")
        print("👤 [SupabaseService] Username: \(username)")
        print("👤 [SupabaseService] Email: \(email)")
        
        let url = URL(string: "\(baseURL)/rest/v1/profiles")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let userData: [String: Any] = [
            "id": id,
            "username": username,
            "email": email,
            "is_admin": false,
            "is_verified": false,
            "created_at": ISO8601DateFormatter().string(from: Date()),
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: userData)
        
        print("📤 [SupabaseService] Sending POST request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to create user")
            }
        }
        
        do {
            let users = try JSONDecoder().decode([User].self, from: data)
            guard let user = users.first else {
                print("❌ [SupabaseService] No user returned")
                throw SupabaseError.unknown
            }
            print("✅ [SupabaseService] Created user: \(user.username)")
            return user
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    // MARK: - Admin Functions
    
    func getAllUsers() async throws -> [User] {
        print("👥 [SupabaseService] Fetching all users...")
        let url = URL(string: "\(baseURL)/rest/v1/profiles?select=*")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        
        print("📤 [SupabaseService] Sending request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw SupabaseError.serverError("Failed to fetch users")
            }
        }
        
        do {
            let users = try JSONDecoder().decode([User].self, from: data)
            print("✅ [SupabaseService] Fetched \(users.count) users")
            return users
        } catch {
            print("❌ [SupabaseService] Decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }
    
    func banUser(userId: String) async throws {
        print("🚫 [SupabaseService] Banning user: \(userId)")
        print("⚠️ [SupabaseService] Ban user not implemented - requires admin API")
    }
    
    func unbanUser(userId: String) async throws {
        print("✅ [SupabaseService] Unbanning user: \(userId)")
        print("⚠️ [SupabaseService] Unban user not implemented - requires admin API")
    }
    
    // MARK: - Realtime Subscriptions
    
    func subscribeToPosts() -> AsyncStream<Post> {
        print("📡 [SupabaseService] Setting up realtime subscription to posts...")
        
        return AsyncStream { continuation in
            // For now, return an empty stream
            // Real implementation would use WebSocket connection to Supabase realtime
            print("⚠️ [SupabaseService] Realtime subscriptions not fully implemented")
            continuation.finish()
        }
    }
}
