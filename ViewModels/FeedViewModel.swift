//
//  FeedViewModel.swift
//  TYLER'S TERMINAL
//

import SwiftUI
import Combine

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var hasMorePosts = true
    
    private var currentOffset = 0
    private let postsPerPage = 20
    
    private var subscriptionTask: Task<Void, Never>?
    private var isSubscribed = false
    
    init() {
        setupNotifications()
    }
    
    deinit {
        subscriptionTask?.cancel()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewTradeNotification),
            name: Notification.Name("NewTradeNotification"),
            object: nil
        )
    }
    
    @objc private func handleNewTradeNotification(_ notification: Notification) {
        Task {
            await refreshPosts()
        }
    }
    
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
    
    func refreshPosts() async {
        isRefreshing = true
        currentOffset = 0
        
        await fetchPosts()
        
        isRefreshing = false
    }
    
    func loadMorePosts() async {
        guard hasMorePosts && !isLoading else { return }
        
        await fetchPosts()
    }
    
    func subscribeToRealtimeUpdates() {
        guard !isSubscribed else { return }
        
        isSubscribed = true
        subscriptionTask = Task {
            let stream = SupabaseService.shared.subscribeToPosts()
            
            for await newPost in stream {
                guard !Task.isCancelled else { break }
                
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
    
    func toggleReaction(postId: String, type: ReactionType) async {
        do {
            try await SupabaseService.shared.toggleReaction(postId: postId, type: type)
            // Refresh posts to update reaction counts
            await refreshPosts()
        } catch {
            errorMessage = "REACTION FAILED"
        }
    }
    
    func fetchComments(for postId: String) async -> [Comment] {
        do {
            return try await SupabaseService.shared.fetchComments(for: postId)
        } catch {
            errorMessage = "FAILED TO LOAD COMMENTS"
            return []
        }
    }
    
    func addComment(postId: String, content: String) async {
        do {
            try await SupabaseService.shared.addComment(postId: postId, content: content)
            // Refresh posts to update comment counts
            await refreshPosts()
        } catch {
            errorMessage = "COMMENT FAILED"
        }
    }
    
    func fetchAllPosts() async -> [Post] {
        do {
            return try await SupabaseService.shared.fetchAllPosts()
        } catch {
            errorMessage = "FAILED TO LOAD POSTS"
            return []
        }
    }
    
    func deletePost(postId: String) async {
        do {
            try await SupabaseService.shared.deletePost(postId: postId)
            await refreshPosts()
        } catch {
            errorMessage = "FAILED TO DELETE POST"
        }
    }
    
    func post(for id: String) -> Post? {
        return posts.first { $0.id == id }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
