//
//  PostDetailView.swift
//  TYLER'S TERMINAL
//
//  Detailed post view with article-style layout
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
                            // Article-style Post
                            articlePostView
                            
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
            .navigationTitle("ARTICLE")
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
    
    // MARK: - Article-style Post View
    private var articlePostView: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Article Header
            articleHeader
            
            // Full Size Image
            fullSizeImage
            
            // Article Content (formatted)
            articleContent
            
            // Engagement Stats
            engagementStats
        }
        .background(TerminalColors.background)
    }
    
    // MARK: - Article Header
    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author row
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundColor(TerminalColors.primary)
                    
                    Text(post.authorUsername.uppercased())
                        .font(TerminalFonts.caption.weight(.bold))
                        .foregroundColor(TerminalColors.textPrimary)
                    
                    Text("·")
                        .foregroundColor(TerminalColors.textSecondary)
                    
                    Text(post.formattedTimestamp)
                        .font(TerminalFonts.caption2)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                
                Spacer()
                
                // Category badge
                Text(post.category.displayName)
                    .font(TerminalFonts.caption2.weight(.bold))
                    .foregroundColor(Color(hex: post.category.color))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(TerminalColors.backgroundTertiary)
                    .cornerRadius(4)
            }
            
            // Ticker pill if present
            if let ticker = post.ticker {
                HStack {
                    Text("$")
                        .font(TerminalFonts.caption.weight(.bold))
                        .foregroundColor(TerminalColors.primary)
                    Text(ticker.uppercased())
                        .font(TerminalFonts.caption.weight(.bold))
                        .foregroundColor(TerminalColors.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TerminalColors.primary.opacity(0.15))
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
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
                .frame(height: 300)
                
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 280)
                    .clipped()
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
                    }
                }
                .frame(height: 200)
                
            @unknown default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Article Content (Formatted)
    private var articleContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            MarkdownContentView(text: post.description)
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
        }
        .background(TerminalColors.background)
    }
    
    // MARK: - Engagement Stats
    private var engagementStats: some View {
        HStack(spacing: 24) {
            HStack(spacing: 6) {
                Text("🔥")
                Text("\(post.fireCount)")
                    .font(TerminalFonts.caption.weight(.medium))
            }
            .foregroundColor(TerminalColors.textSecondary)
            
            HStack(spacing: 6) {
                Text("💯")
                Text("\(post.hundredCount)")
                    .font(TerminalFonts.caption.weight(.medium))
            }
            .foregroundColor(TerminalColors.textSecondary)
            
            HStack(spacing: 6) {
                Text("❤️")
                Text("\(post.heartCount)")
                    .font(TerminalFonts.caption.weight(.medium))
            }
            .foregroundColor(TerminalColors.textSecondary)
            
            Spacer()
            
            HStack(spacing: 6) {
                Image(systemName: "bubble.left")
                    .font(.caption)
                Text("\(post.commentCount)")
                    .font(TerminalFonts.caption.weight(.medium))
            }
            .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TerminalColors.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(TerminalColors.border)
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }
    
    // MARK: - Admin Thread Section
    private var adminThreadSection: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(TerminalColors.primary.opacity(0.1))
            
            // Admin's thread comments
            ForEach(comments.filter { $0.authorUsername.lowercased() == "tyler" }) { comment in
                AdminThreadRow(comment: comment)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(TerminalColors.backgroundSecondary)
                
                Divider()
                    .background(TerminalColors.border)
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Follow Section
    private var followSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: isFollowing ? "bell.fill" : "bell")
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(TerminalColors.backgroundTertiary)
                        .cornerRadius(16)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(TerminalColors.backgroundSecondary)
        .padding(.top, 16)
    }
    
    // MARK: - Comments Section
    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COMMENTS")
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.textPrimary)
                
                Text("(\(comments.count))")
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textSecondary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(TerminalColors.backgroundTertiary)
            
            if comments.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left")
                        .font(.title2)
                        .foregroundColor(TerminalColors.textTertiary)
                    Text("NO COMMENTS YET")
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
                .background(TerminalColors.backgroundSecondary)
            } else {
                ForEach(comments) { comment in
                    CommentRow(comment: comment)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(TerminalColors.backgroundSecondary)
                    
                    Divider()
                        .background(TerminalColors.border)
                        .padding(.leading, 16)
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Input Bar
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField(authViewModel.currentUser?.isAdmin == true ? "Add update..." : "Add a comment...", text: $newComment)
                .font(TerminalFonts.body)
                .foregroundColor(TerminalColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(TerminalColors.backgroundTertiary)
                .cornerRadius(20)
            
            Button(action: submitComment) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(newComment.isEmpty ? TerminalColors.textSecondary : TerminalColors.primary)
            }
            .disabled(newComment.isEmpty || isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(TerminalColors.backgroundSecondary)
        .overlay(
            Rectangle()
                .fill(TerminalColors.border)
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)
        )
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

// MARK: - Markdown Content View (Proper Parser)
struct MarkdownContentView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseContent(text), id: \.id) { element in
                renderElement(element)
            }
        }
    }
    
    private func renderElement(_ element: MarkdownElement) -> some View {
        Group {
            switch element.type {
            case .title(let level, let content):
                Text(content)
                    .font(titleFont(for: level))
                    .foregroundColor(TerminalColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                
            case .bold(let content):
                Text(content)
                    .font(TerminalFonts.body.weight(.bold))
                    .foregroundColor(TerminalColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            case .italic(let content):
                Text(content)
                    .font(TerminalFonts.body)
                    .italic()
                    .foregroundColor(TerminalColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            case .bullet(let items):
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("•")
                                .font(TerminalFonts.body)
                                .foregroundColor(TerminalColors.primary)
                            Text(item)
                                .font(TerminalFonts.body)
                                .foregroundColor(TerminalColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
            case .numbered(let items):
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(TerminalFonts.body)
                                .foregroundColor(TerminalColors.primary)
                            Text(item)
                                .font(TerminalFonts.body)
                                .foregroundColor(TerminalColors.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
            case .quote(let content):
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(TerminalColors.primary)
                        .frame(width: 3)
                    
                    Text(content)
                        .font(TerminalFonts.body)
                        .italic()
                        .foregroundColor(TerminalColors.textSecondary)
                        .padding(.leading, 12)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                
            case .horizontalLine:
                Rectangle()
                    .fill(TerminalColors.border)
                    .frame(height: 1)
                    .padding(.vertical, 8)
                
            case .link(let text, let url):
                Link(destination: URL(string: url) ?? URL(string: "https://")!) {
                    Text(text)
                        .font(TerminalFonts.body)
                        .foregroundColor(TerminalColors.primary)
                        .underline()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
            case .plain(let content):
                Text(content)
                    .font(TerminalFonts.body)
                    .foregroundColor(TerminalColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func titleFont(for level: Int) -> Font {
        switch level {
        case 1: return .system(size: 24, weight: .bold, design: .default)
        case 2: return .system(size: 20, weight: .bold, design: .default)
        case 3: return .system(size: 18, weight: .semibold, design: .default)
        default: return .system(size: 16, weight: .semibold, design: .default)
        }
    }
}

// MARK: - Markdown Parser
enum MarkdownType {
    case title(level: Int, content: String)
    case bold(content: String)
    case italic(content: String)
    case bullet(items: [String])
    case numbered(items: [String])
    case quote(content: String)
    case horizontalLine
    case link(text: String, url: String)
    case plain(content: String)
}

struct MarkdownElement: Identifiable {
    let id = UUID()
    let type: MarkdownType
}

func parseContent(_ text: String) -> [MarkdownElement] {
    var elements: [MarkdownElement] = []
    let lines = text.components(separatedBy: .newlines)
    
    var i = 0
    while i < lines.count {
        let line = lines[i].trimmingCharacters(in: .whitespaces)
        
        // Empty line - skip
        if line.isEmpty {
            i += 1
            continue
        }
        
        // Horizontal line
        if line == "---" || line == "***" || line == "___" {
            elements.append(MarkdownElement(type: .horizontalLine))
            i += 1
            continue
        }
        
        // Title (# Title)
        if line.hasPrefix("# ") {
            let content = String(line.dropFirst(2))
            elements.append(MarkdownElement(type: .title(level: 1, content: processInlineFormatting(content))))
            i += 1
            continue
        }
        if line.hasPrefix("## ") {
            let content = String(line.dropFirst(3))
            elements.append(MarkdownElement(type: .title(level: 2, content: processInlineFormatting(content))))
            i += 1
            continue
        }
        if line.hasPrefix("### ") {
            let content = String(line.dropFirst(4))
            elements.append(MarkdownElement(type: .title(level: 3, content: processInlineFormatting(content))))
            i += 1
            continue
        }
        
        // Quote (> quote)
        if line.hasPrefix("> ") {
            let content = String(line.dropFirst(2))
            elements.append(MarkdownElement(type: .quote(content: processInlineFormatting(content))))
            i += 1
            continue
        }
        
        // Bullet list (- item)
        if line.hasPrefix("- ") || line.hasPrefix("* ") {
            var items: [String] = []
            while i < lines.count {
                let currentLine = lines[i].trimmingCharacters(in: .whitespaces)
                if currentLine.hasPrefix("- ") {
                    items.append(processInlineFormatting(String(currentLine.dropFirst(2))))
                    i += 1
                } else if currentLine.hasPrefix("* ") {
                    items.append(processInlineFormatting(String(currentLine.dropFirst(2))))
                    i += 1
                } else if currentLine.isEmpty {
                    i += 1
                    break
                } else {
                    break
                }
            }
            elements.append(MarkdownElement(type: .bullet(items: items)))
            continue
        }
        
        // Numbered list (1. item)
        let numberedPattern = try! NSRegularExpression(pattern: "^\\d+\\\\.\\s*(.+)$", options: [])
        let numberedRange = NSRange(line.startIndex..., in: line)
        if numberedPattern.firstMatch(in: line, options: [], range: numberedRange) != nil {
            var items: [String] = []
            while i < lines.count {
                let currentLine = lines[i].trimmingCharacters(in: .whitespaces)
                let currentRange = NSRange(currentLine.startIndex..., in: currentLine)
                if let match = numberedPattern.firstMatch(in: currentLine, options: [], range: currentRange) {
                    if let range = Range(match.range(at: 1), in: currentLine) {
                        items.append(processInlineFormatting(String(currentLine[range])))
                    }
                    i += 1
                } else if currentLine.isEmpty {
                    i += 1
                    break
                } else {
                    break
                }
            }
            elements.append(MarkdownElement(type: .numbered(items: items)))
            continue
        }
        
        // Regular paragraph - process inline formatting
        elements.append(MarkdownElement(type: .plain(content: processInlineFormatting(line))))
        i += 1
    }
    
    return elements
}

func processInlineFormatting(_ text: String) -> String {
    var result = text
    
    // Bold: **text** -> just remove markers for display
    result = result.replacingOccurrences(of: "**", with: "")
    
    // Italic: *text* or _text_
    result = result.replacingOccurrences(of: "*", with: "")
    result = result.replacingOccurrences(of: "_", with: "", options: .literal)
    
    return result
}

// MARK: - Admin Thread Row
struct AdminThreadRow: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                        .foregroundColor(TerminalColors.primary)
                    
                    Text("UPDATE")
                        .font(TerminalFonts.caption2.weight(.bold))
                        .foregroundColor(TerminalColors.primary)
                }
                
                Spacer()
                
                Text(comment.formattedTimestamp)
                    .font(TerminalFonts.caption2)
                    .foregroundColor(TerminalColors.textSecondary)
            }
            
            Text(comment.content)
                .font(TerminalFonts.body)
                .foregroundColor(TerminalColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// Note: CommentRow is defined in FeedView.swift
