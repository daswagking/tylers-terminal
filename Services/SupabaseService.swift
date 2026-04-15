import Foundation

// MARK: - Supabase Configuration
struct SupabaseConfig {
    static let projectURL = "https://mlfuoqeabrsxfzvdvlkw.supabase.co"
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZnVvcWVhYnJzeGZ6dmR2bGt3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUxNjkxNDEsImV4cCI6MjA5MDc0NTE0MX0.Ga64BiamlcsrjSzdulq-7VxPLR3q8glDGospqi5c9po"
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sZnVvcWVhYnJzeGZ6dmR2bGt3Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NTE2OTE0MSwiZXhwIjoyMDkwNzQ1MTQxfQ.swSNj4TUEJ1Ip8v0xKuWCpxgguW3zYHSInWfwDJV5co"
}

// MARK: - Request Models (only used internally by SupabaseService)
struct CreatePostRequest: Codable {
    let user_id: String
    let title: String
    let content: String
    let image_url: String?
    let author_name: String?
    let is_pinned: Bool?
    let tags: [String]?
}

struct CreateCommentRequest: Codable {
    let post_id: String
    let user_id: String
    let content: String
    let author_name: String
}

struct ToggleReactionRequest: Codable {
    let post_id: String
    let user_id: String
    let reaction_type: String
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
    
    // MARK: - Posts
    
    func fetchPosts() async throws -> [Post] {
        print("📥 [SupabaseService] Fetching posts...")
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch posts"])
            }
        }
        
        let posts = try JSONDecoder().decode([Post].self, from: data)
        print("✅ [SupabaseService] Fetched \(posts.count) posts")
        return posts
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch post"])
            }
        }
        
        let posts = try JSONDecoder().decode([Post].self, from: data)
        guard let post = posts.first else {
            print("❌ [SupabaseService] Post not found")
            throw NSError(domain: "SupabaseError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Post not found"])
        }
        print("✅ [SupabaseService] Fetched post: \(post.title)")
        return post
    }
    
    func createPost(title: String, content: String, imageUrl: String? = nil, authorName: String? = nil, isPinned: Bool = false, tags: [String]? = nil) async throws -> Post {
        print("📝 [SupabaseService] Creating post...")
        print("📝 [SupabaseService] Title: \(title)")
        print("📝 [SupabaseService] Content length: \(content.count)")
        print("📝 [SupabaseService] Image URL: \(imageUrl ?? "nil")")
        print("📝 [SupabaseService] Author: \(authorName ?? "nil")")
        print("📝 [SupabaseService] Is Pinned: \(isPinned)")
        print("📝 [SupabaseService] Tags: \(tags ?? [])")
        
        let url = URL(string: "\(baseURL)/rest/v1/posts")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let postRequest = CreatePostRequest(
            user_id: adminUserId,
            title: title,
            content: content,
            image_url: imageUrl,
            author_name: authorName,
            is_pinned: isPinned,
            tags: tags
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONEncoder().encode(postRequest)
        
        print("📤 [SupabaseService] Sending POST request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create post"])
            }
        }
        
        let posts = try JSONDecoder().decode([Post].self, from: data)
        guard let post = posts.first else {
            print("❌ [SupabaseService] No post returned")
            throw NSError(domain: "SupabaseError", code: 500, userInfo: [NSLocalizedDescriptionKey: "No post returned"])
        }
        print("✅ [SupabaseService] Created post with id: \(post.id)")
        return post
    }
    
    func updatePost(id: String, title: String? = nil, content: String? = nil, imageUrl: String? = nil, isPinned: Bool? = nil, tags: [String]? = nil) async throws -> Post {
        print("✏️ [SupabaseService] Updating post: \(id)")
        print("✏️ [SupabaseService] Title: \(title ?? "nil")")
        print("✏️ [SupabaseService] Content: \(content != nil ? "provided" : "nil")")
        print("✏️ [SupabaseService] Image URL: \(imageUrl ?? "nil")")
        print("✏️ [SupabaseService] Is Pinned: \(isPinned != nil ? String(isPinned!) : "nil")")
        print("✏️ [SupabaseService] Tags: \(tags ?? [])")
        
        let url = URL(string: "\(baseURL)/rest/v1/posts?id=eq.\(id)")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        var updates: [String: Any] = [:]
        if let title = title { updates["title"] = title }
        if let content = content { updates["content"] = content }
        if let imageUrl = imageUrl { updates["image_url"] = imageUrl }
        if let isPinned = isPinned { updates["is_pinned"] = isPinned }
        if let tags = tags { updates["tags"] = tags }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: updates)
        
        print("📤 [SupabaseService] Sending PATCH request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to update post"])
            }
        }
        
        let posts = try JSONDecoder().decode([Post].self, from: data)
        guard let post = posts.first else {
            print("❌ [SupabaseService] No post returned")
            throw NSError(domain: "SupabaseError", code: 500, userInfo: [NSLocalizedDescriptionKey: "No post returned"])
        }
        print("✅ [SupabaseService] Updated post: \(post.title)")
        return post
    }
    
    func deletePost(id: String) async throws {
        print("🗑️ [SupabaseService] Deleting post: \(id)")
        let url = URL(string: "\(baseURL)/rest/v1/posts?id=eq.\(id)")!
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete post"])
            }
        }
        print("✅ [SupabaseService] Post deleted successfully")
    }
    
    // MARK: - Comments
    
    func fetchComments(postId: String) async throws -> [Comment] {
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch comments"])
            }
        }
        
        let comments = try JSONDecoder().decode([Comment].self, from: data)
        print("✅ [SupabaseService] Fetched \(comments.count) comments")
        return comments
    }
    
    func createComment(postId: String, content: String, authorName: String) async throws -> Comment {
        print("💬 [SupabaseService] Creating comment...")
        print("💬 [SupabaseService] Post ID: \(postId)")
        print("💬 [SupabaseService] Content: \(content)")
        print("💬 [SupabaseService] Author: \(authorName)")
        
        let url = URL(string: "\(baseURL)/rest/v1/comments")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let commentRequest = CreateCommentRequest(
            post_id: postId,
            user_id: adminUserId,
            content: content,
            author_name: authorName
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONEncoder().encode(commentRequest)
        
        print("📤 [SupabaseService] Sending POST request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create comment"])
            }
        }
        
        let comments = try JSONDecoder().decode([Comment].self, from: data)
        guard let comment = comments.first else {
            print("❌ [SupabaseService] No comment returned")
            throw NSError(domain: "SupabaseError", code: 500, userInfo: [NSLocalizedDescriptionKey: "No comment returned"])
        }
        print("✅ [SupabaseService] Created comment with id: \(comment.id)")
        return comment
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete comment"])
            }
        }
        print("✅ [SupabaseService] Comment deleted successfully")
    }
    
    // MARK: - Reactions
    
    func fetchReactions(postId: String) async throws -> [Reaction] {
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch reactions"])
            }
        }
        
        let reactions = try JSONDecoder().decode([Reaction].self, from: data)
        print("✅ [SupabaseService] Fetched \(reactions.count) reactions")
        for reaction in reactions {
            print("   - \(reaction.reaction_type) by \(reaction.user_id)")
        }
        return reactions
    }
    
    func toggleReaction(postId: String, reactionType: String) async throws -> Bool {
        print("🔄 [SupabaseService] Toggling reaction...")
        print("🔄 [SupabaseService] Post ID: \(postId)")
        print("🔄 [SupabaseService] Reaction Type: \(reactionType)")
        print("🔄 [SupabaseService] User ID: \(adminUserId)")
        
        // First, check if user already has this reaction
        print("🔍 [SupabaseService] Checking existing reactions...")
        let existingReactions = try await fetchReactions(postId: postId)
        print("🔍 [SupabaseService] Found \(existingReactions.count) total reactions")
        
        let userReaction = existingReactions.first { $0.user_id == adminUserId && $0.reaction_type == reactionType }
        
        if let existingReaction = userReaction {
            // User already has this reaction, remove it
            print("🗑️ [SupabaseService] Found existing reaction, removing: \(existingReaction.id)")
            try await deleteReaction(id: existingReaction.id)
            print("✅ [SupabaseService] Reaction removed")
            return false // Reaction removed
        } else {
            // User doesn't have this reaction, add it
            print("➕ [SupabaseService] No existing reaction found, adding new reaction")
            try await addReaction(postId: postId, reactionType: reactionType)
            print("✅ [SupabaseService] Reaction added")
            return true // Reaction added
        }
    }
    
    private func addReaction(postId: String, reactionType: String) async throws {
        print("➕ [SupabaseService] Adding reaction...")
        print("➕ [SupabaseService] Post ID: \(postId)")
        print("➕ [SupabaseService] Reaction Type: \(reactionType)")
        print("➕ [SupabaseService] User ID: \(adminUserId)")
        
        let url = URL(string: "\(baseURL)/rest/v1/reactions")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let reactionRequest = ToggleReactionRequest(
            post_id: postId,
            user_id: adminUserId,
            reaction_type: reactionType
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONEncoder().encode(reactionRequest)
        
        print("📤 [SupabaseService] Sending POST request...")
        print("📤 [SupabaseService] Request body: \(String(data: request.httpBody!, encoding: .utf8) ?? "nil")")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                let errorString = String(data: data, encoding: .utf8) ?? "nil"
                print("❌ [SupabaseService] Error response: \(errorString)")
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to add reaction: \(errorString)"])
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to delete reaction"])
            }
        }
        print("✅ [SupabaseService] Reaction deleted successfully")
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image"])
            }
        }
        
        let imageUrl = "\(baseURL)/storage/v1/object/public/\(bucketName)/\(filename)"
        print("✅ [SupabaseService] Image uploaded: \(imageUrl)")
        return imageUrl
    }
    
    // MARK: - User Profile
    
    func fetchUserProfile(userId: String) async throws -> UserProfile {
        print("👤 [SupabaseService] Fetching user profile: \(userId)")
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user profile"])
            }
        }
        
        let profiles = try JSONDecoder().decode([UserProfile].self, from: data)
        guard let profile = profiles.first else {
            print("❌ [SupabaseService] Profile not found")
            throw NSError(domain: "SupabaseError", code: 404, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])
        }
        print("✅ [SupabaseService] Fetched profile: \(profile.email)")
        return profile
    }
    
    func createUserProfile(id: String, email: String, fullName: String? = nil) async throws -> UserProfile {
        print("👤 [SupabaseService] Creating user profile...")
        print("👤 [SupabaseService] ID: \(id)")
        print("👤 [SupabaseService] Email: \(email)")
        print("👤 [SupabaseService] Full Name: \(fullName ?? "nil")")
        
        let url = URL(string: "\(baseURL)/rest/v1/profiles")!
        print("🌐 [SupabaseService] URL: \(url)")
        
        let profile: [String: Any] = [
            "id": id,
            "email": email,
            "full_name": fullName ?? "",
            "created_at": ISO8601DateFormatter().string(from: Date())
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = getHeaders(useServiceRole: true)
        request.httpBody = try JSONSerialization.data(withJSONObject: profile)
        
        print("📤 [SupabaseService] Sending POST request...")
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("📊 [SupabaseService] Response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 201 {
                print("❌ [SupabaseService] Error response: \(String(data: data, encoding: .utf8) ?? "nil")")
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create user profile"])
            }
        }
        
        let profiles = try JSONDecoder().decode([UserProfile].self, from: data)
        guard let userProfile = profiles.first else {
            print("❌ [SupabaseService] No profile returned")
            throw NSError(domain: "SupabaseError", code: 500, userInfo: [NSLocalizedDescriptionKey: "No profile returned"])
        }
        print("✅ [SupabaseService] Created profile: \(userProfile.email)")
        return userProfile
    }
    
    // MARK: - Admin Functions
    
    func getAllUsers() async throws -> [UserProfile] {
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
                throw NSError(domain: "SupabaseError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch users"])
            }
        }
        
        let users = try JSONDecoder().decode([UserProfile].self, from: data)
        print("✅ [SupabaseService] Fetched \(users.count) users")
        return users
    }
    
    func banUser(userId: String) async throws {
        print("🚫 [SupabaseService] Banning user: \(userId)")
        // This would require admin API or custom function
        // For now, we can add a banned flag to the profile
        print("⚠️ [SupabaseService] Ban user not implemented - requires admin API")
    }
    
    func unbanUser(userId: String) async throws {
        print("✅ [SupabaseService] Unbanning user: \(userId)")
        // This would require admin API or custom function
        print("⚠️ [SupabaseService] Unban user not implemented - requires admin API")
    }
}
