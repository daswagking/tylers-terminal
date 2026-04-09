//
//  PostDetailView.swift
//  TYLER'S TERMINAL
//
//  Detailed post view with full content and comments
//

import SwiftUI

struct PostDetailView: View {
    let post: Post
    @EnvironmentObject var feedViewModel: FeedViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var comments: [Comment] = []
    @State private var newComment: String = ""
    @State private var isLoading = false
    @State private var isFollowing = false
    @State private var showFollowers = false
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Scrollable content
                    ScrollView {
                        VStack(spacing: 0) {
                            // Full Post Card
                            fullPostCard
                            
                            // Admin Thread Section (if admin)
                            if authViewModel.currentUser?.isAdmin == true {
                                adminThreadSection
                            }
                            
                            // Follow Button (for non-admin users)
                            if authViewModel.currentUser?.isAdmin != true {
                                followSection
                            }
                            
                            // Comments Section
                            commentsSection
                        }
                    }
                    
                    // Input Bar
                    inputBar
                }
            }
            .navigationTitle("POST DETAIL")
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
            checkIfFollowing()
        }
    }
    
    // MARK: - Full Post Card
    private var fullPostCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            postHeader
            
            // Full Size Image (tappable for zoom)
            fullSizeImage
            
            // Full Description
            fullDescription
            
            // Engagement Stats
            engagementStats
        }
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
    }
    
    // MARK: - Post Header
    private var postHeader: some View {
        HStack {
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
            
            Text(post.category.displayName)
                .font(TerminalFonts.caption2.weight(.bold))
                .foregroundColor(Color(hex: post.category.color))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(TerminalColors.backgroundTertiary)
                .border(Color(hex: post.category.color), width: 1)
            
            Text(post.formattedTimestamp)
                .font(TerminalFonts.timestamp)
                .foregroundColor(TerminalColors.textSecondary)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundTertiary)
    }
    
    // MARK: - Full Size Image
    private var fullSizeImage: some View {
        AsyncImage(url: URL(string: post.imageUrl)) { phase in
            switch phase {
            case .empty:
                ZStack {
                    TerminalColors.backgroundTertiary
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: TerminalColors.primary))
                }
                .frame(height: 400)
                
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(TerminalColors.backgroundTertiary)
                    .onTapGesture {
                        // Could add zoom/fullscreen view here
                    }
                
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
                    }
                }
                .frame(height: 300)
                
            @unknown default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Full Description
    private var fullDescription: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Ticker if present
            if let ticker = post.ticker {
                Text(ticker.uppercased())
                    .font(TerminalFonts.ticker)
                    .foregroundColor(TerminalColors.primary)
            }
            
            // Formatted description
            FormattedTextView(text: post.description)
                .font(TerminalFonts.body)
                .foregroundColor(TerminalColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
    
    // MARK: - Engagement Stats
    private var engagementStats: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Text("🔥")
                Text("\(post.fireCount)")
            }
            .font(TerminalFonts.caption)
            .foregroundColor(TerminalColors.textSecondary)
            
            HStack(spacing: 4) {
                Text("💯")
                Text("\(post.hundredCount)")
            }
            .font(TerminalFonts.caption)
            .foregroundColor(TerminalColors.textSecondary)
            
            HStack(spacing: 4) {
                Text("❤️")
                Text("\(post.heartCount)")
            }
            .font(TerminalFonts.caption)
            .foregroundColor(TerminalColors.textSecondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                Text("\(post.commentCount)")
            }
            .font(TerminalFonts.caption)
            .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundTertiary)
        .border(TerminalColors.border, width: 1)
    }
    
    // MARK: - Admin Thread Section
    private var adminThreadSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundColor(TerminalColors.primary)
                Text("THREAD UPDATES")
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.primary)
                
                Spacer()
                
                Text("\(comments.filter { $0.authorUsername.lowercased() == "tyler" }.count) UPDATES")
                    .font(TerminalFonts.caption2)
                    .foregroundColor(TerminalColors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TerminalColors.primary.opacity(0.1))
            .border(TerminalColors.primary, width: 1)
            
            // Admin's thread comments
            ForEach(comments.filter { $0.authorUsername.lowercased() == "tyler" }) { comment in
                AdminThreadRow(comment: comment)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
    
    // MARK: - Follow Section
    private var followSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundColor(isFollowing ? TerminalColors.positive : TerminalColors.textSecondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(isFollowing ? "FOLLOWING THREAD" : "FOLLOW THIS THREAD")
                        .font(TerminalFonts.caption.weight(.bold))
                        .foregroundColor(isFollowing ? TerminalColors.positive : TerminalColors.textPrimary)
                    
                    Text("Get notified of updates from TYLER")
                        .font(TerminalFonts.caption2)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                
                Spacer()
                
                Button(action: toggleFollow) {
                    Text(isFollowing ? "UNFOLLOW" : "FOLLOW")
                        .font(TerminalFonts.caption2.weight(.bold))
                        .foregroundColor(isFollowing ? TerminalColors.alert : TerminalColors.positive)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(TerminalColors.backgroundTertiary)
                        .border(isFollowing ? TerminalColors.alert : TerminalColors.positive, width: 1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(TerminalColors.backgroundSecondary)
            .border(TerminalColors.border, width: 1)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
    
    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COMMENTS (\(comments.count))")
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TerminalColors.backgroundTertiary)
            .border(TerminalColors.border, width: 1)
            
            if comments.isEmpty {
                Text("NO COMMENTS YET")
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TerminalColors.backgroundSecondary)
            } else {
                ForEach(comments) { comment in
                    CommentRow(comment: comment)
                        .background(TerminalColors.backgroundSecondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField(authViewModel.currentUser?.isAdmin == true ? "ADD UPDATE..." : "ADD COMMENT...", text: $newComment)
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
    
    // MARK: - Functions
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
    
    private func checkIfFollowing() {
        // Check if user is following this post
        let followedPosts = UserDefaults.standard.stringArray(forKey: "followedPosts") ?? []
        isFollowing = followedPosts.contains(post.id)
    }
    
    private func toggleFollow() {
        var followedPosts = UserDefaults.standard.stringArray(forKey: "followedPosts") ?? []
        
        if isFollowing {
            followedPosts.removeAll { $0 == post.id }
        } else {
            followedPosts.append(post.id)
        }
        
        UserDefaults.standard.set(followedPosts, forKey: "followedPosts")
        isFollowing.toggle()
    }
}

// MARK: - Admin Thread Row
struct AdminThreadRow: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.caption2)
                    .foregroundColor(TerminalColors.primary)
                
                Text("UPDATE")
                    .font(TerminalFonts.caption2.weight(.bold))
                    .foregroundColor(TerminalColors.primary)
                
                Spacer()
                
                Text(comment.formattedTimestamp)
                    .font(TerminalFonts.caption2)
                    .foregroundColor(TerminalColors.textSecondary)
            }
            
            Text(comment.content)
                .font(TerminalFonts.body)
                .foregroundColor(TerminalColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.primary.opacity(0.3), width: 1)
    }
}

// MARK: - Formatted Text View
struct FormattedTextView: View {
    let text: String
    
    var body: some View {
        // Parse markdown-like formatting
        let formatted = parseFormattedText(text)
        Text(formatted)
    }
    
    private func parseFormattedText(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        
        // Bold: **text**
        let boldPattern = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
        let boldMatches = boldPattern.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        for match in boldMatches.reversed() {
            if let range = Range(match.range, in: result) {
                result[range].font = .system(.body, design: .monospaced).weight(.bold)
            }
        }
        
        // Links: [text](url)
        let linkPattern = try! NSRegularExpression(pattern: "\\[(.+?)\\]\\((.+?)\\)", options: [])
        let linkMatches = linkPattern.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        for match in linkMatches.reversed() {
            if let range = Range(match.range, in: result) {
                result[range].foregroundColor = TerminalColors.primary
                result[range].underlineStyle = .single
            }
        }
        
        return result
    }
}
