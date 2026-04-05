//
//  RequestMarketView.swift
//  TYLER'S TERMINAL
//

import SwiftUI

struct RequestMarketView: View {
    @EnvironmentObject var viewModel: RequestMarketViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Header
                    searchHeader
                    
                    // Search Results
                    if viewModel.hasSearchResults {
                        searchResultsList
                    }
                    
                    // Custom Request Form
                    if viewModel.showCustomRequest {
                        customRequestForm
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("REQUEST MARKET")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(TerminalColors.primary)
                        Text("REQUEST MARKET")
                            .font(TerminalFonts.header3)
                            .foregroundColor(TerminalColors.primary)
                    }
                }
                
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
    
    // MARK: - Search Header
    private var searchHeader: some View {
        VStack(spacing: 16) {
            // Search Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(TerminalColors.textSecondary)
                
                TextField("ENTER TICKER...", text: $viewModel.searchQuery)
                    .font(TerminalFonts.bodyMono)
                    .foregroundColor(TerminalColors.textPrimary)
                    .autocapitalization(.allCharacters)
                    .onChange(of: viewModel.searchQuery) { _ in
                        viewModel.debouncedSearch()
                    }
                
                if viewModel.isSearching {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: TerminalColors.primary))
                }
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(TerminalColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(TerminalColors.backgroundTertiary)
            .border(TerminalColors.border, width: 1)
            .padding(.horizontal, 16)
            
            // Category Selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AssetRequest.AssetCategory.allCases, id: \.self) { category in
                        Button(action: {
                            viewModel.selectCategory(category)
                        }) {
                            Text(category.displayName)
                                .font(TerminalFonts.caption2.weight(.bold))
                                .foregroundColor(viewModel.selectedCategory == category ? .black : TerminalColors.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(viewModel.selectedCategory == category ? TerminalColors.primary : TerminalColors.backgroundTertiary)
                                .border(viewModel.selectedCategory == category ? TerminalColors.primary : TerminalColors.border, width: 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            
            // Custom Request Toggle
            Button(action: {
                viewModel.showCustomRequest.toggle()
            }) {
                HStack {
                    Image(systemName: viewModel.showCustomRequest ? "checkmark.square.fill" : "square")
                        .foregroundColor(TerminalColors.primary)
                    Text("CUSTOM REQUEST")
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.textSecondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Search Results
    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.searchResults, id: \.ticker) { result in
                    Button(action: {
                        viewModel.selectResult(result)
                    }) {
                        HStack(spacing: 12) {
                            Text(result.ticker)
                                .font(TerminalFonts.ticker)
                                .foregroundColor(Color(hex: result.category.color))
                            
                            Spacer()
                            
                            Text(result.category.displayName)
                                .font(TerminalFonts.caption2)
                                .foregroundColor(TerminalColors.textSecondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(TerminalColors.backgroundTertiary)
                                .border(TerminalColors.border, width: 1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(TerminalColors.backgroundSecondary)
                    .border(TerminalColors.border, width: 1)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(maxHeight: 200)
    }
    
    // MARK: - Custom Request Form
    private var customRequestForm: some View {
        VStack(spacing: 16) {
            Text("CUSTOM REQUEST DETAILS")
                .font(TerminalFonts.caption.weight(.bold))
                .foregroundColor(TerminalColors.textSecondary)
            
            TextEditor(text: $viewModel.customDescription)
                .font(TerminalFonts.bodyMono)
                .foregroundColor(TerminalColors.textPrimary)
                .frame(height: 100)
                .padding(8)
                .background(TerminalColors.backgroundTertiary)
                .border(TerminalColors.border, width: 1)
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview
struct RequestMarketView_Previews: PreviewProvider {
    static var previews: some View {
        RequestMarketView()
            .environmentObject(RequestMarketViewModel())
    }
}
