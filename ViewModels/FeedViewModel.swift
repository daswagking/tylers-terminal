//
//  FeedViewModel.swift
//  TYLER'S TERMINAL
//
//  Feed state management and real-time updates
//

import SwiftUI
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var hasMorePosts = true
    
    // MARK: - Pagination
    private var currentOffset = 0
    private let postsPerPage = 20
    
    // MARK: - Real-time Subscription
    private var subscriptionTask: Task<Void, Never>?
    private var isSubscribed = false
    
    // MARK: - Initialization
    init() {
        setupNotifications()
    }
    
    deinit {
        subscriptionTask?.cancel()
    }
    
    // MARK: - Notification Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewTradeNotification),
            name: Notification.Name("NewTradeNotification"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppBackground),
            name: Notification.Name("AppDidEnterBackground"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppForeground),
            name: Notification.Name("AppWillEnterForeground"),
            object: nil
        )
    }
    
    @objc private func handleNewTradeNotification(_ notification: Notification) {
        // Refresh feed when new trade notification received
        Task {
            await refreshPosts()
        }
    }
    
    @objc private func handleAppBackground() {
        // Unsubscribe from real-time updates
        subscriptionTask?.cancel()
        isSubscribed = false
    }
    
    @objc private func handleAppForeground() {
        // Resubscribe to real-time updates
        subscribeToRealtimeUpdates()
    }
    
    // MARK: - Fetch Posts
    func fetchPosts() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newPosts = try await SupabaseService.shared.fetchPosts(
                limit: postsPerPage,
                offset: currentOffset
            )
            
            if currentOffset == 0 {
                posts = newPosts
            } else {
                posts.append(contentsOf: newPosts)
            }
            
            hasMorePosts = newPosts.count == postsPerPage
            currentOffset += newPosts.count
            
        } catch let error as SupabaseError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "CONNECTION LOST"
        }
        
        isLoading = false
    }
    
    // MARK: - Refresh Posts
    func refreshPosts() async {
        isRefreshing = true
        currentOffset = 0
        
        await fetchPosts()
        
        isRefreshing = false
    }
    
    // MARK: - Load More
    func loadMorePosts() async {
        guard hasMorePosts && !isLoading else { return }
        
        await fetchPosts()
    }
    
    // MARK: - Real-time Subscription
    func subscribeToRealtimeUpdates() {
        guard !isSubscribed else { return }
        
        isSubscribed = true
        subscriptionTask = Task {
            let stream = SupabaseService.shared.subscribeToPosts()
            
            for await newPost in stream {
                guard !Task.isCancelled else { break }
                
                // Insert new post at the beginning if not already present
                if !posts.contains(where: { $0.id == newPost.id }) {
                    await MainActor.run {
                        withAnimation(.easeIn(duration: 0.3)) {
                            posts.insert(newPost, at: 0)
                        }
                    }
                }
            }
        }
    }
    
    func unsubscribeFromRealtimeUpdates() {
        subscriptionTask?.cancel()
        isSubscribed = false
    }
    
    // MARK: - Reactions
    func toggleReaction(postId: UUID, type: ReactionType) async {
        do {
            try await SupabaseService.shared.toggleReaction(postId: postId, type: type)
            
            // Update local state
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                var post = posts[index]
                
                // Toggle reaction count
                switch type {
                case .fire:
                    if post.userReactions?.hasFired == true {
                        post.fireCount -= 1
                        post.userReactions?.hasFired = false
                    } else {
                        post.fireCount += 1
                        post.userReactions?.hasFired = true
                    }
                case .hundred:
                    if post.userReactions?.hasHundred == true {
                        post.hundredCount -= 1
                        post.userReactions?.hasHundred = false
                    } else {
                        post.hundredCount += 1
                        post.userReactions?.hasHundred = true
                    }
                case .heart:
                    if post.userReactions?.hasHeart == true {
                        post.heartCount -= 1
                        post.userReactions?.hasHeart = false
                    } else {
                        post.heartCount += 1
                        post.userReactions?.hasHeart = true
                    }
                }
                
                posts[index] = post
            }
            
        } catch {
            errorMessage = "REACTION FAILED"
        }
    }
    
    // MARK: - Comments
    func fetchComments(for postId: UUID) async -> [Comment] {
        do {
            return try await SupabaseService.shared.fetchComments(postId: postId)
        } catch {
            errorMessage = "FAILED TO LOAD COMMENTS"
            return []
        }
    }
    
    func addComment(postId: UUID, content: String) async {
        do {
            try await SupabaseService.shared.addComment(postId: postId, content: content)
            
            // Update comment count locally
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index].commentCount += 1
            }
            
        } catch {
            errorMessage = "COMMENT FAILED"
        }
    }
    
    // MARK: - Admin Methods
    func fetchAllPosts() async -> [Post] {
        do {
            return try await SupabaseService.shared.fetchAllPosts()
        } catch {
            errorMessage = "FAILED TO LOAD POSTS"
            return []
        }
    }
    
    func deletePost(postId: UUID) async {
        do {
            try await SupabaseService.shared.deletePost(postId: postId)
            await refreshPosts()
        } catch {
            errorMessage = "FAILED TO DELETE POST"
        }
    }
    
    // MARK: - Helper Methods
    func post(for id: UUID) -> Post? {
        return posts.first { $0.id == id }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
