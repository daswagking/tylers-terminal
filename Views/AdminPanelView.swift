//
//  AdminPanelView.swift
//  TYLER'S TERMINAL
//
//  Admin control panel for managing users, posts, and content
//

import SwiftUI
import Combine

struct AdminPanelView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab: AdminTab = .posts
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    enum AdminTab: String, CaseIterable {
        case posts = "POSTS"
        case users = "USERS"
        case analytics = "ANALYTICS"
        
        var icon: String {
            switch self {
            case .posts: return "doc.text"
            case .users: return "person.3"
            case .analytics: return "chart.bar"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Admin Header
                    adminHeader
                    
                    // Tab Selection
                    tabSelection
                    
                    // Content
                    contentView
                }
            }
            .navigationTitle("ADMIN PANEL")
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
    }
    
    // MARK: - Admin Header
    private var adminHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "shield.fill")
                    .font(.title2)
                    .foregroundColor(TerminalColors.primary)
                
                VStack(alignment: .leading) {
                    Text("ADMINISTRATOR")
                        .font(TerminalFonts.header3)
                        .foregroundColor(TerminalColors.primary)
                    
                    Text(authViewModel.currentUser?.terminalId ?? "")
                        .font(TerminalFonts.caption2)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(TerminalColors.backgroundSecondary)
            .border(TerminalColors.primary, width: 1)
            .padding(.horizontal, 16)
            .padding(.top, 16)
        }
    }
    
    // MARK: - Tab Selection
    private var tabSelection: some View {
        HStack(spacing: 0) {
            ForEach(AdminTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 16))
                        Text(tab.rawValue)
                            .font(TerminalFonts.caption2.weight(.bold))
                    }
                    .foregroundColor(selectedTab == tab ? TerminalColors.primary : TerminalColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedTab == tab ? TerminalColors.primary.opacity(0.1) : Color.clear)
                }
            }
        }
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        switch selectedTab {
        case .posts:
            AdminPostsView()
        case .users:
            AdminUsersView()
        case .analytics:
            AdminAnalyticsView()
        }
    }
}

// MARK: - Admin Posts View
struct AdminPostsView: View {
    @EnvironmentObject var feedViewModel: FeedViewModel
    @State private var posts: [Post] = []
    @State private var isLoading = false
    @State private var selectedPost: Post?
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: TerminalColors.primary))
                    .padding()
            } else if posts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 48))
                        .foregroundColor(TerminalColors.textTertiary)
                    Text("NO POSTS")
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                .padding(.top, 64)
            } else {
                List {
                    ForEach(posts) { post in
                        AdminPostRow(post: post)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    selectedPost = post
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("DELETE", systemImage: "trash")
                                }
                            }
                            .listRowBackground(TerminalColors.backgroundSecondary)
                    }
                }
                .listStyle(PlainListStyle())
                .background(TerminalColors.background)
            }
        }
        .onAppear {
            loadPosts()
        }
        .alert("DELETE POST?", isPresented: $showDeleteConfirmation) {
            Button("CANCEL", role: .cancel) {}
            Button("DELETE", role: .destructive) {
                if let post = selectedPost {
                    deletePost(post)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func loadPosts() {
        Task {
            isLoading = true
            posts = await feedViewModel.fetchAllPosts()
            isLoading = false
        }
    }
    
    private func deletePost(_ post: Post) {
        Task {
            do {
                try await SupabaseService.shared.deletePost(postId: post.id)
                await loadPosts()
            } catch {
                print("Failed to delete post: \(error)")
            }
        }
    }
}

// MARK: - Admin Post Row
struct AdminPostRow: View {
    let post: Post
    
    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            AsyncImage(url: URL(string: post.imageUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(TerminalColors.backgroundTertiary)
            }
            .frame(width: 60, height: 60)
            .clipped()
            .border(TerminalColors.border, width: 1)
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(post.ticker ?? "NO TICKER")
                        .font(TerminalFonts.ticker)
                        .foregroundColor(TerminalColors.primary)
                    
                    Spacer()
                    
                    Text(post.formattedTimestamp)
                        .font(TerminalFonts.caption2)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                
                Text(post.description.truncated(to: 50))
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label("\(post.fireCount)", systemImage: "flame")
                    Label("\(post.commentCount)", systemImage: "bubble.left")
                }
                .font(TerminalFonts.caption2)
                .foregroundColor(TerminalColors.textSecondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Admin Users View
struct AdminUsersView: View {
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var selectedUser: User?
    @State private var showBanConfirmation = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: TerminalColors.primary))
                    .padding()
            } else if users.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.3")
                        .font(.system(size: 48))
                        .foregroundColor(TerminalColors.textTertiary)
                    Text("NO USERS")
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                .padding(.top, 64)
            } else {
                List {
                    ForEach(users) { user in
                        AdminUserRow(user: user)
                            .swipeActions(edge: .trailing) {
                                if !user.isAdmin {
                                    Button(role: .destructive) {
                                        selectedUser = user
                                        showBanConfirmation = true
                                    } label: {
                                        Label("BAN", systemImage: "person.fill.xmark")
                                    }
                                }
                            }
                            .listRowBackground(TerminalColors.backgroundSecondary)
                    }
                }
                .listStyle(PlainListStyle())
                .background(TerminalColors.background)
            }
        }
        .onAppear {
            loadUsers()
        }
        .alert("BAN USER?", isPresented: $showBanConfirmation) {
            Button("CANCEL", role: .cancel) {}
            Button("BAN", role: .destructive) {
                if let user = selectedUser {
                    banUser(user)
                }
            }
        } message: {
            Text("This user will be permanently banned.")
        }
    }
    
    private func loadUsers() {
        Task {
            isLoading = true
            do {
                users = try await SupabaseService.shared.fetchAllUsers()
            } catch {
                print("Failed to load users: \(error)")
            }
            isLoading = false
        }
    }
    
    private func banUser(_ user: User) {
        Task {
            do {
                try await SupabaseService.shared.banUser(userId: user.id)
                await loadUsers()
            } catch {
                print("Failed to ban user: \(error)")
            }
        }
    }
}

// MARK: - Admin User Row
struct AdminUserRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            ZStack {
                Rectangle()
                    .fill(user.isAdmin ? TerminalColors.primary.opacity(0.2) : TerminalColors.backgroundTertiary)
                    .frame(width: 44, height: 44)
                    .border(user.isAdmin ? TerminalColors.primary : TerminalColors.border, width: 1)
                
                Text(user.displayName.prefix(2))
                    .font(TerminalFonts.bodyMono.weight(.bold))
                    .foregroundColor(user.isAdmin ? TerminalColors.primary : TerminalColors.textPrimary)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(user.displayName)
                        .font(TerminalFonts.body.weight(.medium))
                        .foregroundColor(TerminalColors.textPrimary)
                    
                    if user.isAdmin {
                        Image(systemName: "shield.fill")
                            .font(.caption2)
                            .foregroundColor(TerminalColors.primary)
                    }
                    
                    Spacer()
                    
                    Text(user.terminalId)
                        .font(TerminalFonts.caption2)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                
                Text("Joined: \(user.formattedDate)")
                    .font(TerminalFonts.caption2)
                    .foregroundColor(TerminalColors.textSecondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Admin Analytics View
struct AdminAnalyticsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("ANALYTICS")
                .font(TerminalFonts.header3)
                .foregroundColor(TerminalColors.textPrimary)
                .padding(.top, 32)
            
            Text("Coming Soon")
                .font(TerminalFonts.body)
                .foregroundColor(TerminalColors.textSecondary)
            
            Spacer()
        }
    }
}

// MARK: - Admin Panel ViewModel
@MainActor
class AdminPanelViewModel: ObservableObject {
    @Published var allPosts: [Post] = []
    @Published var allUsers: [User] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var totalReactions: Int {
        allPosts.reduce(0) { $0 + $1.fireCount + $1.hundredCount + $1.heartCount }
    }
    
    var totalComments: Int {
        allPosts.reduce(0) { $0 + $1.commentCount }
    }
    
    func loadData() async {
        await loadPosts()
        await loadUsers()
    }
    
    func loadPosts() async {
        do {
            allPosts = try await SupabaseService.shared.fetchAllPosts()
        } catch {
            errorMessage = "Failed to load posts"
        }
    }
    
    func loadUsers() async {
        do {
            allUsers = try await SupabaseService.shared.fetchAllUsers()
        } catch {
            errorMessage = "Failed to load users"
        }
    }
    
    func deletePost(_ post: Post) async {
        do {
            try await SupabaseService.shared.deletePost(postId: post.id)
            await loadPosts()
        } catch {
            errorMessage = "Failed to delete post"
        }
    }
    
    func banUser(_ user: User) async {
        do {
            try await SupabaseService.shared.banUser(userId: user.id)
            await loadUsers()
        } catch {
            errorMessage = "Failed to ban user"
        }
    }
}
