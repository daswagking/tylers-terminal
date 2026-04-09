//
//  NewPostView.swift
//  TYLER'S TERMINAL
//
//  Create new trade post with rich formatting
//

import SwiftUI
import PhotosUI

struct NewPostView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var feedViewModel: FeedViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // MARK: - Form State
    @State private var description: String = ""
    @State private var ticker: String = ""
    @State private var selectedCategory: Post.PostCategory = .trade
    @State private var selectedImage: UIImage?
    @State private var imageSelection: PhotosPickerItem?
    
    // MARK: - UI State
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showFormattingHelp = false
    @State private var postType: PostType = .standard
    
    // MARK: - Post Type
    enum PostType: String, CaseIterable {
        case standard = "STANDARD"
        case thread = "THREAD"
        case quick = "QUICK UPDATE"
        
        var icon: String {
            switch self {
            case .standard: return "doc.text"
            case .thread: return "bubble.left.and.bubble.right"
            case .quick: return "bolt.fill"
            }
        }
        
        var description: String {
            switch self {
            case .standard: return "Full post with image"
            case .thread: return "Start a thread with updates"
            case .quick: return "Quick text-only update"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Status Bar
                    statusBar
                    
                    // Form
                    ScrollView {
                        VStack(spacing: 16) {
                            // Post Type Selector (Admin only)
                            if authViewModel.currentUser?.isAdmin == true {
                                postTypeSelector
                            }
                            
                            // Image Picker (if not quick post)
                            if postType != .quick {
                                imagePickerSection
                            }
                            
                            // Category Selector
                            categorySelector
                            
                            // Ticker Input
                            tickerInput
                            
                            // Description with formatting toolbar
                            descriptionSection
                            
                            // Submit Button
                            submitButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("NEW POST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CANCEL") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.alert)
                }
            }
            .photosPicker(isPresented: .constant(false), selection: $imageSelection, matching: .images)
            .onChange(of: imageSelection) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            selectedImage = uiImage
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(isLoading ? TerminalColors.warning : TerminalColors.positive)
                    .frame(width: 8, height: 8)
                Text(isLoading ? "UPLOADING..." : "READY")
                    .font(TerminalFonts.caption2)
                    .foregroundColor(isLoading ? TerminalColors.warning : TerminalColors.positive)
            }
            
            Spacer()
            
            if let error = errorMessage {
                Text(error)
                    .font(TerminalFonts.caption2)
                    .foregroundColor(TerminalColors.alert)
                    .lineLimit(1)
            } else if let success = successMessage {
                Text(success)
                    .font(TerminalFonts.caption2)
                    .foregroundColor(TerminalColors.positive)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text("\(description.count) CHARS")
                .font(TerminalFonts.caption2)
                .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
    }
    
    // MARK: - Post Type Selector
    private var postTypeSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("POST TYPE")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
            
            HStack(spacing: 8) {
                ForEach(PostType.allCases, id: \.self) { type in
                    Button(action: { postType = type }) {
                        VStack(spacing: 4) {
                            Image(systemName: type.icon)
                                .font(.system(size: 20))
                            Text(type.rawValue)
                                .font(TerminalFonts.caption2.weight(.bold))
                        }
                        .foregroundColor(postType == type ? .black : TerminalColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(postType == type ? TerminalColors.primary : TerminalColors.backgroundTertiary)
                        .border(postType == type ? TerminalColors.primary : TerminalColors.border, width: 1)
                    }
                }
            }
            
            Text(postType.description)
                .font(TerminalFonts.caption2)
                .foregroundColor(TerminalColors.textSecondary)
        }
    }
    
    // MARK: - Image Picker Section
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SCREENSHOT (OPTIONAL)")
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textSecondary)
                
                Spacer()
                
                if selectedImage != nil {
                    Button(action: { selectedImage = nil }) {
                        Text("REMOVE")
                            .font(TerminalFonts.caption2.weight(.bold))
                            .foregroundColor(TerminalColors.alert)
                    }
                }
            }
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .background(TerminalColors.backgroundTertiary)
                    .border(TerminalColors.border, width: 1)
            } else {
                PhotosPicker(selection: $imageSelection, matching: .images) {
                    ZStack {
                        TerminalColors.backgroundTertiary
                            .frame(height: 120)
                        
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.system(size: 32))
                                .foregroundColor(TerminalColors.textSecondary)
                            Text("TAP TO SELECT IMAGE")
                                .font(TerminalFonts.caption)
                                .foregroundColor(TerminalColors.textSecondary)
                        }
                    }
                    .border(TerminalColors.border, width: 1)
                }
            }
        }
    }
    
    // MARK: - Category Selector
    private var categorySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CATEGORY")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
            
            HStack(spacing: 8) {
                ForEach(Post.PostCategory.allCases, id: \.self) { category in
                    Button(action: { selectedCategory = category }) {
                        Text(category.displayName)
                            .font(TerminalFonts.caption2.weight(.bold))
                            .foregroundColor(selectedCategory == category ? .black : Color(hex: category.color))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? Color(hex: category.color) : TerminalColors.backgroundTertiary)
                            .border(Color(hex: category.color), width: 1)
                    }
                }
            }
        }
    }
    
    // MARK: - Ticker Input
    private var tickerInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TICKER (OPTIONAL)")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
            
            HStack(spacing: 8) {
                Text("$")
                    .font(TerminalFonts.bodyMono)
                    .foregroundColor(TerminalColors.primary)
                
                TextField("AAPL", text: $ticker)
                    .font(TerminalFonts.bodyMono)
                    .foregroundColor(TerminalColors.textPrimary)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(TerminalColors.backgroundTertiary)
            .border(TerminalColors.border, width: 1)
        }
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("DESCRIPTION")
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textSecondary)
                
                Spacer()
                
                // Formatting help button
                Button(action: { showFormattingHelp.toggle() }) {
                    Image(systemName: "textformat")
                        .foregroundColor(TerminalColors.primary)
                }
            }
            
            // Formatting toolbar (Admin only)
            if authViewModel.currentUser?.isAdmin == true {
                formattingToolbar
            }
            
            // Formatting help
            if showFormattingHelp {
                formattingHelp
            }
            
            // Text editor
            TextEditor(text: $description)
                .font(TerminalFonts.bodyMono)
                .foregroundColor(TerminalColors.textPrimary)
                .frame(minHeight: 120)
                .padding(8)
                .background(TerminalColors.backgroundTertiary)
                .border(TerminalColors.border, width: 1)
        }
    }
    
    // MARK: - Formatting Toolbar
    private var formattingToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FormatButton(icon: "bold", text: "BOLD", action: { insertFormatting("**", "**") })
                FormatButton(icon: "textformat.title", text: "TITLE", action: { insertFormatting("# ", "") })
                FormatButton(icon: "list.bullet", text: "BULLET", action: { insertFormatting("- ", "") })
                FormatButton(icon: "number", text: "NUMBER", action: { insertFormatting("1. ", "") })
                FormatButton(icon: "link", text: "LINK", action: { insertFormatting("[", "](url)") })
                FormatButton(icon: "text.quote", text: "QUOTE", action: { insertFormatting("> ", "") })
                FormatButton(icon: "minus", text: "LINE", action: { insertFormatting("\n---\n", "") })
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Formatting Help
    private var formattingHelp: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FORMATTING GUIDE:")
                .font(TerminalFonts.caption2.weight(.bold))
                .foregroundColor(TerminalColors.primary)
            
            Group {
                Text("**bold** = bold text")
                Text("# Title = large title")
                Text("- item = bullet point")
                Text("1. item = numbered list")
                Text("> quote = blockquote")
                Text("[text](url) = hyperlink")
                Text("--- = horizontal line")
            }
            .font(TerminalFonts.caption2)
            .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(8)
        .background(TerminalColors.backgroundTertiary)
        .border(TerminalColors.primary.opacity(0.3), width: 1)
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: submitPost) {
            HStack {
                Image(systemName: "paperplane.fill")
                Text(postType == .thread ? "START THREAD" : "POST")
                    .font(TerminalFonts.caption.weight(.bold))
            }
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? TerminalColors.primary : TerminalColors.textSecondary)
            .border(canSubmit ? TerminalColors.primary : TerminalColors.textSecondary, width: 1)
        }
        .disabled(!canSubmit || isLoading)
    }
    
    // MARK: - Computed Properties
    private var canSubmit: Bool {
        !description.isEmpty
    }
    
    // MARK: - Functions
    private func insertFormatting(_ prefix: String, _ suffix: String) {
        // Simple insertion at end for now
        description += prefix + suffix
    }
    
    private func submitPost() {
        guard !description.isEmpty else {
            errorMessage = "DESCRIPTION REQUIRED"
            return
        }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                var imageUrl: String
                
                if let image = selectedImage,
                   let imageData = image.jpegData(compressionQuality: 0.8) {
                    // Upload image to Supabase Storage
                    let filename = "\(UUID().uuidString).jpg"
                    imageUrl = try await SupabaseService.shared.uploadImage(imageData, filename: filename)
                } else {
                    // No image - use placeholder
                    imageUrl = "https://via.placeholder.com/400x300/1a1a1a/00ff00?text=NO+IMAGE"
                }
                
                // Create the post with the image URL
                try await SupabaseService.shared.createPost(
                    imageUrl: imageUrl,
                    description: description,
                    ticker: ticker.isEmpty ? nil : ticker.uppercased(),
                    category: selectedCategory
                )
                
                await MainActor.run {
                    successMessage = postType == .thread ? "THREAD STARTED!" : "POST CREATED!"
                    isLoading = false
                    
                    // Clear form
                    selectedImage = nil
                    imageSelection = nil
                    description = ""
                    ticker = ""
                    
                    // Refresh feed
                    Task {
                        await feedViewModel.refreshPosts()
                    }
                    
                    // Dismiss after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "FAILED: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Format Button
struct FormatButton: View {
    let icon: String
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(text)
                    .font(TerminalFonts.caption2)
            }
            .foregroundColor(TerminalColors.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(TerminalColors.backgroundTertiary)
            .border(TerminalColors.border, width: 1)
        }
    }
}
