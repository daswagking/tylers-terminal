//
//  NewPostView.swift
//  TYLER'S TERMINAL
//
//  Admin-only view for creating new trade posts
//

import SwiftUI
import PhotosUI

struct NewPostView: View {
    @EnvironmentObject var feedViewModel: FeedViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedImage: UIImage?
    @State private var imageSelection: PhotosPickerItem?
    @State private var description: String = ""
    @State private var ticker: String = ""
    @State private var selectedCategory: Post.PostCategory = .trade
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Admin Badge
                        adminBadge
                        
                        // Image Picker
                        imagePickerSection
                        
                        // Ticker Input
                        tickerInput
                        
                        // Category Selection
                        categorySelection
                        
                        // Description
                        descriptionInput
                        
                        // Messages
                        messageSection
                        
                        // Submit Button
                        submitButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("NEW TRADE POST")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CANCEL") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Admin Badge
    private var adminBadge: some View {
        HStack {
            Image(systemName: "shield.fill")
                .foregroundColor(TerminalColors.primary)
            Text("ADMIN ACCESS")
                .font(TerminalFonts.caption.weight(.bold))
                .foregroundColor(TerminalColors.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TerminalColors.primary.opacity(0.1))
        .border(TerminalColors.primary, width: 1)
    }
    
    // MARK: - Image Picker Section
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCREENSHOT (OPTIONAL)")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .border(TerminalColors.border, width: 1)
                    .overlay(
                        Button(action: { selectedImage = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(TerminalColors.alert)
                                .background(TerminalColors.background)
                                .clipShape(Circle())
                        }
                        .padding(8),
                        alignment: .topTrailing
                    )
            } else {
                PhotosPicker(selection: $imageSelection, matching: .images) {
                    ZStack {
                        Rectangle()
                            .fill(TerminalColors.backgroundTertiary)
                            .frame(height: 200)
                            .border(TerminalColors.border, width: 1)
                        
                        VStack(spacing: 12) {
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(TerminalColors.textSecondary)
                            Text("TAP TO SELECT IMAGE")
                                .font(TerminalFonts.caption)
                                .foregroundColor(TerminalColors.textSecondary)
                        }
                    }
                }
                .onChange(of: imageSelection) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
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
            
            TextField("e.g., AAPL, BTC", text: $ticker)
                .font(TerminalFonts.ticker)
                .foregroundColor(TerminalColors.textPrimary)
                .autocapitalization(.allCharacters)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(TerminalColors.backgroundTertiary)
                .border(TerminalColors.border, width: 1)
        }
    }
    
    // MARK: - Category Selection
    private var categorySelection: some View {
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
    
    // MARK: - Description Input
    private var descriptionInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DESCRIPTION")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
            
            TextEditor(text: $description)
                .font(TerminalFonts.body)
                .foregroundColor(TerminalColors.textPrimary)
                .frame(minHeight: 100)
                .padding(8)
                .background(TerminalColors.backgroundTertiary)
                .border(TerminalColors.border, width: 1)
        }
    }
    
    // MARK: - Message Section
    private var messageSection: some View {
        Group {
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(TerminalColors.alert)
                    Text(error)
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.alert)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(TerminalColors.backgroundTertiary)
                .border(TerminalColors.alert, width: 1)
            }
            
            if let success = successMessage {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(TerminalColors.positive)
                    Text(success)
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.positive)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(TerminalColors.backgroundTertiary)
                .border(TerminalColors.positive, width: 1)
            }
        }
    }
    
    // MARK: - Submit Button
    private var submitButton: some View {
        Button(action: submitPost) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("POST TRADE")
                        .font(TerminalFonts.bodyMono.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSubmit ? TerminalColors.primary : TerminalColors.textSecondary)
            .foregroundColor(.black)
        }
        .disabled(!canSubmit || isLoading)
        .padding(.top, 8)
    }
    
    // MARK: - Computed Properties
    private var canSubmit: Bool {
        !description.isEmpty
    }
    
    // MARK: - Submit Post
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
                    successMessage = "POST CREATED SUCCESSFULLY"
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
                // Print full error details to console
                print("❌ POST ERROR: \(error)")
                print("❌ POST ERROR LOCALIZED: \(error.localizedDescription)")
                
                await MainActor.run {
                    errorMessage = "FAILED TO CREATE POST: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}
