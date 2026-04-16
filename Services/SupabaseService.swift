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
        case .networkError: return "Network connection failed"
        case .decodingError: return "Failed to parse data"
        case .serverError(let message): return message
        case .notFound: return "Resource not found"
        case .unauthorized: return "Unauthorized access"
        case .unknown: return "Unknown error occurred"
        case .invalidCredentials: return "Invalid username or password"
        }
    }
}

// MARK: - User Response (for decoding from Supabase profiles table)
struct UserResponse: Codable {
    let id: String
    let username: String
    let email: String
    let password_hash: String?
    let is_admin: Bool?
    let is_verified: Bool?
    let created_at: String?
    let updated_at: String?
}

// MARK: - Supabase Service
class SupabaseService {
    static let shared = SupabaseService()

    private let baseURL: String
    private let anonKey: String
    private let serviceRoleKey: String

    // Currently logged-in user context
    private(set) var currentUserId: String?
    private(set) var currentUsername: String?

    private init() {
        self.baseURL = SupabaseConfig.projectURL
        self.anonKey = SupabaseConfig.anonKey
        self.serviceRoleKey = SupabaseConfig.serviceRoleKey
    }

    // MARK: - Current User Context

    func setCurrentUser(id: String, username: String) {
        currentUserId = id
        currentUsername = username
    }

    func clearCurrentUser() {
        currentUserId = nil
        currentUsername = nil
    }

    // MARK: - Headers

    private func getHeaders() -> [String: String] {
        return [
            "Content-Type": "application/json",
            "apikey": serviceRoleKey,
            "Authorization": "Bearer \(serviceRoleKey)",
            "Prefer": "return=representation"
        ]
    }

    private func getDeleteHeaders() -> [String: String] {
        return [
            "Content-Type": "application/json",
            "apikey": serviceRoleKey,
            "Authorization": "Bearer \(serviceRoleKey)"
        ]
    }

    // MARK: - Password Hashing (base64 for demo)
    private func hashPassword(_ password: String) -> String {
        let data = Data(password.utf8)
        return data.base64EncodedString()
    }

    // MARK: - URL Encoding Helper
    private func urlEncoded(_ string: String) -> String {
        return string.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? string
    }

    // MARK: - Sign In / Sign Up

    func signIn(username: String, password: String) async throws -> User {
        let encodedUsername = urlEncoded(username)
        guard let url = URL(string: "\(baseURL)/rest/v1/profiles?username=eq.\(encodedUsername)&select=*") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.invalidCredentials
        }

        do {
            let users = try JSONDecoder().decode([UserResponse].self, from: data)
            guard let userResponse = users.first else {
                throw SupabaseError.invalidCredentials
            }

            let hashedInput = hashPassword(password)
            if let storedHash = userResponse.password_hash, !storedHash.isEmpty {
                guard storedHash == hashedInput else {
                    throw SupabaseError.invalidCredentials
                }
            }

            let user = User(
                id: userResponse.id,
                username: userResponse.username,
                email: userResponse.email,
                isAdmin: userResponse.is_admin ?? false,
                isVerified: userResponse.is_verified ?? false
            )
            setCurrentUser(id: user.id, username: user.username)
            return user
        } catch let error as SupabaseError {
            throw error
        } catch {
            throw SupabaseError.decodingError
        }
    }

    func signUp(username: String, password: String) async throws -> User {
        let encodedUsername = urlEncoded(username)
        guard let checkUrl = URL(string: "\(baseURL)/rest/v1/profiles?username=eq.\(encodedUsername)&select=id") else {
            throw SupabaseError.networkError
        }

        var checkRequest = URLRequest(url: checkUrl)
        checkRequest.httpMethod = "GET"
        checkRequest.allHTTPHeaderFields = getHeaders()

        let (checkData, _) = try await URLSession.shared.data(for: checkRequest)

        if let existingUsers = try? JSONDecoder().decode([[String: String]].self, from: checkData),
           !existingUsers.isEmpty {
            throw SupabaseError.serverError("Username already exists")
        }

        let userId = UUID().uuidString
        let email = "\(username.lowercased())@tylersterminal.local"
        let passwordHash = hashPassword(password)

        guard let url = URL(string: "\(baseURL)/rest/v1/profiles") else {
            throw SupabaseError.networkError
        }

        let userData: [String: Any] = [
            "id": userId,
            "username": username,
            "email": email,
            "password_hash": passwordHash,
            "is_admin": false,
            "is_verified": false
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: userData)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            let errorString = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseError.serverError("Failed to create user: \(errorString)")
        }

        let user = User(id: userId, username: username, email: email)
        setCurrentUser(id: user.id, username: user.username)
        return user
    }

    func signOut() {
        clearCurrentUser()
    }

    // MARK: - Push Notifications

    func updatePushNotifications(enabled: Bool) async throws {
        guard let userId = currentUserId else { throw SupabaseError.unauthorized }
        guard let url = URL(string: "\(baseURL)/rest/v1/profiles?id=eq.\(userId)") else {
            throw SupabaseError.networkError
        }

        let updateData: [String: Any] = ["push_notifications_enabled": enabled]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = getDeleteHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            let errorString = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseError.serverError("Failed to update push notifications: \(errorString)")
        }
    }

    // MARK: - Posts

    func fetchPosts(limit: Int = 20, offset: Int = 0) async throws -> [Post] {
        guard let url = URL(string: "\(baseURL)/rest/v1/posts?select=*&order=created_at.desc&limit=\(limit)&offset=\(offset)") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch posts")
        }

        do {
            return try JSONDecoder().decode([Post].self, from: data)
        } catch {
            print("[SupabaseService] Post decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }

    func fetchAllPosts() async throws -> [Post] {
        guard let url = URL(string: "\(baseURL)/rest/v1/posts?select=*&order=created_at.desc") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch posts")
        }

        do {
            return try JSONDecoder().decode([Post].self, from: data)
        } catch {
            throw SupabaseError.decodingError
        }
    }

    func fetchPost(id: String) async throws -> Post {
        guard let url = URL(string: "\(baseURL)/rest/v1/posts?id=eq.\(id)&select=*") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch post")
        }

        let posts = try JSONDecoder().decode([Post].self, from: data)
        guard let post = posts.first else { throw SupabaseError.notFound }
        return post
    }

    func createPost(description: String, imageUrl: String, ticker: String? = nil, category: Post.PostCategory = .trade, authorUsername: String) async throws -> Post {
        guard let url = URL(string: "\(baseURL)/rest/v1/posts") else {
            throw SupabaseError.networkError
        }

        var postData: [String: Any] = [
            "author_username": authorUsername,
            "image_url": imageUrl,
            "description": description,
            "ticker": ticker ?? "",
            "category": category.rawValue,
            "fire_count": 0,
            "hundred_count": 0,
            "heart_count": 0,
            "comment_count": 0,
            "is_verified": false
        ]

        if let userId = currentUserId {
            postData["author_id"] = userId
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: postData)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            let errorString = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseError.serverError("Failed to create post: \(errorString)")
        }

        let posts = try JSONDecoder().decode([Post].self, from: data)
        guard let post = posts.first else { throw SupabaseError.unknown }
        return post
    }

    func deletePost(postId: String) async throws {
        guard let url = URL(string: "\(baseURL)/rest/v1/posts?id=eq.\(postId)") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = getDeleteHeaders()

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw SupabaseError.serverError("Failed to delete post")
        }
    }

    // MARK: - Comments

    func fetchComments(for postId: String) async throws -> [Comment] {
        guard let url = URL(string: "\(baseURL)/rest/v1/comments?post_id=eq.\(postId)&select=*&order=created_at.asc") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch comments")
        }

        do {
            return try JSONDecoder().decode([Comment].self, from: data)
        } catch {
            print("[SupabaseService] Comment decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }

    func addComment(postId: String, content: String) async throws {
        guard let url = URL(string: "\(baseURL)/rest/v1/comments") else {
            throw SupabaseError.networkError
        }

        let authorId = currentUserId ?? ""
        let authorName = currentUsername ?? "anonymous"

        var commentData: [String: Any] = [
            "post_id": postId,
            "author_username": authorName,
            "content": content
        ]
        if !authorId.isEmpty {
            commentData["author_id"] = authorId
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getDeleteHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: commentData)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            let errorString = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseError.serverError("Failed to create comment: \(errorString)")
        }

        // Increment comment_count on the post
        try await incrementCommentCount(postId: postId)
    }

    private func incrementCommentCount(postId: String) async throws {
        let post = try await fetchPost(id: postId)
        guard let url = URL(string: "\(baseURL)/rest/v1/posts?id=eq.\(postId)") else { return }

        let updateData: [String: Any] = ["comment_count": post.commentCount + 1]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = getDeleteHeaders()
        request.httpBody = try? JSONSerialization.data(withJSONObject: updateData)

        _ = try? await URLSession.shared.data(for: request)
    }

    func deleteComment(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/rest/v1/comments?id=eq.\(id)") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = getDeleteHeaders()

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw SupabaseError.serverError("Failed to delete comment")
        }
    }

    // MARK: - Reactions

    func fetchReactions(for postId: String) async throws -> [Reaction] {
        guard let url = URL(string: "\(baseURL)/rest/v1/reactions?post_id=eq.\(postId)&select=*") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch reactions")
        }

        do {
            return try JSONDecoder().decode([Reaction].self, from: data)
        } catch {
            throw SupabaseError.decodingError
        }
    }

    func toggleReaction(postId: String, type: ReactionType) async throws {
        guard let userId = currentUserId else { throw SupabaseError.unauthorized }

        let existingReactions = try await fetchReactions(for: postId)
        let userReaction = existingReactions.first { $0.userId == userId && $0.type == type }

        if let existingReaction = userReaction {
            try await deleteReaction(id: existingReaction.id)
            try await updateReactionCount(postId: postId, type: type, increment: false)
        } else {
            try await addReaction(postId: postId, type: type, userId: userId)
            try await updateReactionCount(postId: postId, type: type, increment: true)
        }
    }

    private func addReaction(postId: String, type: ReactionType, userId: String) async throws {
        guard let url = URL(string: "\(baseURL)/rest/v1/reactions") else {
            throw SupabaseError.networkError
        }

        let reactionData: [String: Any] = [
            "post_id": postId,
            "user_id": userId,
            "type": type.rawValue
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getDeleteHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: reactionData)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            let errorString = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseError.serverError("Failed to add reaction: \(errorString)")
        }
    }

    private func deleteReaction(id: String) async throws {
        guard let url = URL(string: "\(baseURL)/rest/v1/reactions?id=eq.\(id)") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.allHTTPHeaderFields = getDeleteHeaders()

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw SupabaseError.serverError("Failed to delete reaction")
        }
    }

    private func updateReactionCount(postId: String, type: ReactionType, increment: Bool) async throws {
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

        guard let url = URL(string: "\(baseURL)/rest/v1/posts?id=eq.\(postId)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = getDeleteHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: updates)

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            throw SupabaseError.serverError("Failed to update reaction count")
        }
    }

    // MARK: - Asset Requests

    func submitAssetRequest(ticker: String, category: AssetRequest.AssetCategory, description: String?) async throws {
        guard let userId = currentUserId else { throw SupabaseError.unauthorized }
        guard let url = URL(string: "\(baseURL)/rest/v1/asset_requests") else {
            throw SupabaseError.networkError
        }

        let requestData: [String: Any] = [
            "user_id": userId,
            "ticker": ticker.uppercased(),
            "category": category.rawValue,
            "description": description ?? "",
            "status": "pending"
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getDeleteHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: requestData)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 201 {
            let errorString = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseError.serverError("Failed to submit asset request: \(errorString)")
        }
    }

    func fetchUserRequests() async throws -> [AssetRequest] {
        guard let userId = currentUserId else { return [] }
        guard let url = URL(string: "\(baseURL)/rest/v1/asset_requests?user_id=eq.\(userId)&select=*&order=created_at.desc") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch user requests")
        }

        do {
            return try JSONDecoder().decode([AssetRequest].self, from: data)
        } catch {
            throw SupabaseError.decodingError
        }
    }

    // MARK: - Notifications

    func fetchNotifications() async throws -> [AppNotification] {
        guard let userId = currentUserId else { return [] }
        guard let url = URL(string: "\(baseURL)/rest/v1/notifications?user_id=eq.\(userId)&select=*&order=created_at.desc") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch notifications")
        }

        do {
            return try JSONDecoder().decode([AppNotification].self, from: data)
        } catch {
            print("[SupabaseService] Notification decoding error: \(error)")
            throw SupabaseError.decodingError
        }
    }

    func markNotificationAsRead(notificationId: String) async throws {
        guard let url = URL(string: "\(baseURL)/rest/v1/notifications?id=eq.\(notificationId)") else {
            throw SupabaseError.networkError
        }

        let updateData: [String: Any] = ["is_read": true]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = getDeleteHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 && httpResponse.statusCode != 204 {
            let errorString = String(data: data, encoding: .utf8) ?? "unknown"
            throw SupabaseError.serverError("Failed to mark notification as read: \(errorString)")
        }
    }

    // MARK: - Image Upload

    func uploadImage(data: Data, filename: String, contentType: String = "image/jpeg") async throws -> String {
        let bucketName = "post-images"
        guard let url = URL(string: "\(baseURL)/storage/v1/object/\(bucketName)/\(filename)") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(serviceRoleKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(serviceRoleKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode != 200 && httpResponse.statusCode != 201 {
            throw SupabaseError.serverError("Failed to upload image")
        }

        return "\(baseURL)/storage/v1/object/public/\(bucketName)/\(filename)"
    }

    // MARK: - User Profile

    func fetchUser(userId: String) async throws -> User {
        guard let url = URL(string: "\(baseURL)/rest/v1/profiles?id=eq.\(userId)&select=*") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch user")
        }

        do {
            let users = try JSONDecoder().decode([User].self, from: data)
            guard let user = users.first else { throw SupabaseError.notFound }
            return user
        } catch {
            throw SupabaseError.decodingError
        }
    }

    // MARK: - Admin Functions

    func fetchAllUsers() async throws -> [User] {
        guard let url = URL(string: "\(baseURL)/rest/v1/profiles?select=*") else {
            throw SupabaseError.networkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = getHeaders()

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw SupabaseError.serverError("Failed to fetch users")
        }

        do {
            return try JSONDecoder().decode([User].self, from: data)
        } catch {
            throw SupabaseError.decodingError
        }
    }

    func banUser(userId: String) async throws {
        // No-op — ban logic would require a `banned` column or auth management
    }

    func unbanUser(userId: String) async throws {
        // No-op
    }

    // MARK: - Realtime Subscriptions

    func subscribeToPosts() -> AsyncStream<Post> {
        return AsyncStream { continuation in
            continuation.finish()
        }
    }
}
