//
//  FeedView.swift
//  TYLER'S TERMINAL
//
//  Main feed with trade posts
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject var feedViewModel: FeedViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedPost: Post?
    @State private var showComments = false
    @State private var showNewPostSheet = false
    @State private var showAdminPanel = false
    @State private var postToDelete: Post?
    @State private var showDeleteConfirmation = false
    @State private var showPostDetail = false
    @State private var detailPost: Post?
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Status Bar
                    statusBar
                    
                    // Feed List
                    feedList
                }
            }
            .navigationTitle("THE FEED")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "terminal")
                            .foregroundColor(TerminalColors.primary)
                        Text("THE FEED")
                            .font(TerminalFonts.header3)
                            .foregroundColor(TerminalColors.primary)
                    }
                }
                
                // Admin buttons (only for admin users)
                if authViewModel.currentUser?.isAdmin == true {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                            // New Post Button
                            Button(action: { showNewPostSheet = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(TerminalColors.primary)
                            }
                            
                            // Admin Panel Button
                            Button(action: { showAdminPanel = true }) {
                                Image(systemName: "shield.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(TerminalColors.primary)
                            }
                        }
                    }
                }
            }
            .sheet(item: $selectedPost) { post in
                CommentsView(post: post)
            }
            .sheet(isPresented: $showNewPostSheet) {
                NewPostView()
            }
            .sheet(isPresented: $showAdminPanel) {
                AdminPanelView()
            }
            .sheet(isPresented: $showPostDetail) {
                if let post = detailPost {
                    PostDetailView(post: post)
                }
            }
            .alert("DELETE POST?", isPresented: $showDeleteConfirmation) {
                Button("CANCEL", role: .cancel) {}
                Button("DELETE", role: .destructive) {
                    if let post = postToDelete {
                        self.deletePost(post)
                    }
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear {
                Task {
                    await feedViewModel.fetchPosts()
                    feedViewModel.subscribeToRealtimeUpdates()
                }
            }
            .onDisappear {
                feedViewModel.unsubscribeFromRealtimeUpdates()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func deletePost(_ post: Post) {
        Task {
            do {
                try await SupabaseService.shared.deletePost(postId: post.id)
                await feedViewModel.refreshPosts()
            } catch {
                print("Failed to delete post: \(error)")
            }
        }
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(feedViewModel.isLoading ? TerminalColors.warning : TerminalColors.positive)
                    .frame(width: 8, height: 8)
                Text(feedViewModel.isLoading ? "CONNECTING..." : "ONLINE")
                    .font(TerminalFonts.caption2)
                    .foregroundColor(feedViewModel.isLoading ? TerminalColors.warning : TerminalColors.positive)
            }
            
            Spacer()
            
            Text("\(feedViewModel.posts.count) POSTS")
                .font(TerminalFonts.caption2)
                .foregroundColor(TerminalColors.textSecondary)
            
            Spacer()
            
            Text(currentTime)
                .font(TerminalFonts.caption2)
                .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
    }
    
    private var currentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: Date())
    }
    
    // MARK: - Feed List
    private var feedList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Pull to refresh indicator
                if feedViewModel.isRefreshing {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: TerminalColors.primary))
                        Text("SCANNING...")
                            .font(TerminalFonts.caption)
                            .foregroundColor(TerminalColors.primary)
                            .padding(.leading, 8)
                    }
                    .padding(.vertical, 16)
                }
                
                // Posts
                ForEach(feedViewModel.posts) { post in
                    PostCardView(
                        post: post,
                        onTap: {
                            detailPost = post
                            showPostDetail = true
                        },
                        onReaction: { type in
                            Task {
                                await feedViewModel.toggleReaction(postId: post.id, type: type)
                            }
                        },
                        onComment: {
                            selectedPost = post
                        },
                        onDelete: authViewModel.currentUser?.isAdmin == true ? {
                            postToDelete = post
                            showDeleteConfirmation = true
                        } : nil
                    )
                    .onAppear {
                        // Load more when reaching near the end
                        if post.id == feedViewModel.posts.last?.id {
                            Task {
                                await feedViewModel.loadMorePosts()
                            }
                        }
                    }
                }
                
                // Loading more indicator
                if feedViewModel.isLoading && !feedViewModel.posts.isEmpty {
                    HStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: TerminalColors.primary))
                        Text("LOADING...")
                            .font(TerminalFonts.caption)
                            .foregroundColor(TerminalColors.textSecondary)
                            .padding(.leading, 8)
                    }
                    .padding(.vertical, 16)
                }
                
                // End of feed
                if !feedViewModel.hasMorePosts && !feedViewModel.posts.isEmpty {
                    Text("--- END OF FEED ---")
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.textTertiary)
                        .padding(.vertical, 24)
                }
            }
        }
        .refreshable {
            await feedViewModel.refreshPosts()
        }
    }
}

// MARK: - Post Card View
struct PostCardView: View {
    let post: Post
    let onTap: () -> Void
    let onReaction: (ReactionType) -> Void
    let onComment: () -> Void
    let onDelete: (() -> Void)?
    
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isExpanded = false
    
    private let maxLines = 3
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            postHeader
            
            // Image (tappable)
            postImage
                .onTapGesture {
                    onTap()
                }
            
            // Description (with "See more...")
            if !post.description.isEmpty {
                postDescription
            }
            
            // Engagement Bar
            engagementBar
        }
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
        .padding(.horizontal, 0)
        .padding(.vertical, 8)
        .contextMenu {
            if authViewModel.currentUser?.isAdmin == true {
                Button(role: .destructive) {
                    onDelete?()
                } label: {
                    Label("DELETE POST", systemImage: "trash")
                }
            }
        }
    }
    
    // MARK: - Post Header
    private var postHeader: some View {
        HStack {
            // Author Badge
            HStack(spacing: 4) {
                Text(post.authorUsername.uppercased())
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.primary)
                
                if post.isVerified {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundColor(TerminalColors.primary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TerminalColors.backgroundTertiary)
            .border(TerminalColors.primary, width: 1)
            
            Spacer()
            
            // Category Tag
            Text(post.category.displayName)
                .font(TerminalFonts.caption2.weight(.bold))
                .foregroundColor(Color(hex: post.category.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(TerminalColors.backgroundTertiary)
                .border(Color(hex: post.category.color), width: 1)
            
            // Timestamp
            Text(post.formattedTimestamp)
                .font(TerminalFonts.timestamp)
                .foregroundColor(TerminalColors.textSecondary)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundTertiary)
    }
    
    // MARK: - Post Image
    private var postImage: some View {
        AsyncImage(url: URL(string: post.imageUrl)) { phase in
            switch phase {
            case .empty:
                ZStack {
                    TerminalColors.backgroundTertiary
                    VStack {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: TerminalColors.primary))
                        Text("LOADING...")
                            .font(TerminalFonts.caption)
                            .foregroundColor(TerminalColors.textSecondary)
                            .padding(.top, 8)
                    }
                }
                .frame(height: 200)
                
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(TerminalColors.backgroundTertiary)
                
            case .failure:
                ZStack {
                    TerminalColors.backgroundTertiary
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(TerminalColors.alert)
                        Text("IMAGE UNAVAILABLE")
                            .font(TerminalFonts.caption)
                            .foregroundColor(TerminalColors.textSecondary)
                            .padding(.top, 8)
                    }
                }
                .frame(height: 200)
                
            @unknown default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Post Description with "See more..."
    private var postDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show ticker if present
            if let ticker = post.ticker {
                HStack {
                    Text("$")
                        .font(TerminalFonts.caption2.weight(.bold))
                        .foregroundColor(TerminalColors.primary)
                    Text(ticker.uppercased())
                        .font(TerminalFonts.caption2.weight(.bold))
                        .foregroundColor(TerminalColors.primary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(TerminalColors.primary.opacity(0.15))
                .cornerRadius(12)
            }
            
            // Description with line limit
            Text(post.description)
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textPrimary)
                .lineLimit(isExpanded ? nil : maxLines)
            
            // "See more..." button if text is long
            if post.description.count > 120 {
                Button(action: {
                    onTap() // Go to detail view instead of expanding
                }) {
                    HStack(spacing: 4) {
                        Text("READ MORE")
                            .font(TerminalFonts.caption2.weight(.bold))
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                    }
                    .foregroundColor(TerminalColors.primary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onTapGesture {
            onTap()
        }
    }
    
    // MARK: - Engagement Bar
    private var engagementBar: some View {
        HStack(spacing: 0) {
            // Fire Button
            reactionButton(
                type: .fire,
                count: post.fireCount,
                isActive: post.userReactions?.hasFired ?? false
            )
            
            Divider()
                .background(TerminalColors.border)
            
            // 100 Button
            reactionButton(
                type: .hundred,
                count: post.hundredCount,
                isActive: post.userReactions?.hasHundred ?? false
            )
            
            Divider()
                .background(TerminalColors.border)
            
            // Heart Button
            reactionButton(
                type: .heart,
                count: post.heartCount,
                isActive: post.userReactions?.hasHeart ?? false
            )
            
            Divider()
                .background(TerminalColors.border)
            
            // Comment Button
            Button(action: onComment) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left")
                        .font(.caption)
                    Text("\(post.commentCount)")
                        .font(TerminalFonts.caption)
                }
                .foregroundColor(TerminalColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
        .background(TerminalColors.backgroundTertiary)
        .border(TerminalColors.border, width: 1)
    }
    
    private func reactionButton(type: ReactionType, count: Int, isActive: Bool) -> some View {
        Button(action: { onReaction(type) }) {
            HStack(spacing: 4) {
                Text(type.emoji)
                    .font(.caption)
                Text("\(count)")
                    .font(TerminalFonts.caption)
            }
            .foregroundColor(isActive ? TerminalColors.primary : TerminalColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isActive ? TerminalColors.primary.opacity(0.1) : Color.clear)
        }
    }
}

// MARK: - Comments View
struct CommentsView: View {
    let post: Post
    @EnvironmentObject var feedViewModel: FeedViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var comments: [Comment] = []
    @State private var newComment: String = ""
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Comments List
                    List {
                        // Original Post
                        Section(header: Text("ORIGINAL POST").font(TerminalFonts.caption)) {
                            HStack {
                                Text(post.description)
                                    .font(TerminalFonts.caption)
                                    .foregroundColor(TerminalColors.textPrimary)
                            }
                            .listRowBackground(TerminalColors.backgroundSecondary)
                        }
                        
                        // Comments
                        Section(header: Text("COMMENTS (\(comments.count))").font(TerminalFonts.caption)) {
                            if comments.isEmpty {
                                Text("NO COMMENTS")
                                    .font(TerminalFonts.caption)
                                    .foregroundColor(TerminalColors.textSecondary)
                                    .listRowBackground(TerminalColors.backgroundSecondary)
                            } else {
                                ForEach(comments) { comment in
                                    CommentRow(comment: comment)
                                        .listRowBackground(TerminalColors.backgroundSecondary)
                                        .listRowSeparator(.hidden)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(TerminalColors.background)
                    
                    // Input Bar
                    inputBar
                }
            }
            .navigationTitle("COMMENTS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("CLOSE") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.primary)
                }
            }
        }
        .onAppear {
            loadComments()
        }
    }
    
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("ADD COMMENT...", text: $newComment)
                .font(TerminalFonts.bodyMono)
                .foregroundColor(TerminalColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(TerminalColors.backgroundTertiary)
                .border(TerminalColors.border, width: 1)
            
            Button(action: submitComment) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 40, height: 40)
                    .background(newComment.isEmpty ? TerminalColors.textSecondary : TerminalColors.primary)
            }
            .disabled(newComment.isEmpty || isLoading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
    }
    
    private func loadComments() {
        Task {
            isLoading = true
            comments = await feedViewModel.fetchComments(for: post.id)
            isLoading = false
        }
    }
    
    private func submitComment() {
        guard !newComment.isEmpty else { return }
        
        Task {
            await feedViewModel.addComment(postId: post.id, content: newComment)
            newComment = ""
            loadComments()
        }
    }
}

// MARK: - Comment Row
struct CommentRow: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.authorUsername.uppercased())
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.primary)
                
                Spacer()
                
                Text(comment.formattedTimestamp)
                    .font(TerminalFonts.caption2)
                    .foregroundColor(TerminalColors.textSecondary)
            }
            
            Text(comment.content)
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textPrimary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
}

// MARK: - Preview
struct FeedView_Previews: PreviewProvider {
    static var previews: some View {
        FeedView()
            .environmentObject(FeedViewModel())
            .preferredColorScheme(.dark)
    }
}
