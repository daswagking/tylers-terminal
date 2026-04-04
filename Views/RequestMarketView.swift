//
//  RequestMarketView.swift
//  TYLER'S TERMINAL
//
//  Search and request market screen
//

import SwiftUI

struct RequestMarketView: View {
    @StateObject private var viewModel = RequestMarketViewModel()
    @State private var showResults = false
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Status Bar
                    statusBar
                    
                    // Search Section
                    searchSection
                    
                    // Category Tags
                    categoryTags
                    
                    // Results or My Requests
                    contentArea
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
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        HStack {
            Text("DATABASE: CONNECTED")
                .font(TerminalFonts.caption2)
                .foregroundColor(TerminalColors.positive)
            
            Spacer()
            
            Text("\(AssetDatabase.allAssets.count) ASSETS")
                .font(TerminalFonts.caption2)
                .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
    }
    
    // MARK: - Search Section
    private var searchSection: some View {
        VStack(spacing: 12) {
            // Search Label
            HStack {
                Text("ENTER TICKER...")
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.primary)
                Spacer()
            }
            
            // Search Input
            HStack(spacing: 8) {
                TextField("", text: $viewModel.searchQuery)
                    .font(TerminalFonts.ticker)
                    .foregroundColor(TerminalColors.primary)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .onChange(of: viewModel.searchQuery) { _ in
                        viewModel.debouncedSearch()
                        showResults = !viewModel.searchQuery.isEmpty
                    }
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                        showResults = false
                    }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(TerminalColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(TerminalColors.backgroundTertiary)
            .border(TerminalColors.primary, width: 1)
            
            // Custom Request Toggle
            if viewModel.searchResults.isEmpty && viewModel.searchQuery.count >= 2 {
                HStack {
                    Toggle("CUSTOM REQUEST", isOn: $viewModel.showCustomRequest)
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.textSecondary)
                        .toggleStyle(SwitchToggleStyle(tint: TerminalColors.primary))
                    
                    Spacer()
                }
            }
            
            // Custom Description (if custom request)
            if viewModel.showCustomRequest {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DESCRIPTION (OPTIONAL)")
                        .font(TerminalFonts.caption2)
                        .foregroundColor(TerminalColors.textSecondary)
                    
                    TextEditor(text: $viewModel.customDescription)
                        .font(TerminalFonts.bodyMono)
                        .foregroundColor(TerminalColors.textPrimary)
                        .frame(height: 80)
                        .padding(4)
                        .background(TerminalColors.backgroundTertiary)
                        .border(TerminalColors.border, width: 1)
                }
            }
            
            // Submit Button
            Button(action: {
                Task {
                    await viewModel.submitRequest()
                    showResults = false
                }
            }) {
                HStack {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(0.8)
                    } else {
                        Text(viewModel.showCustomRequest ? "SUBMIT CUSTOM REQUEST" : "REQUEST ANALYSIS")
                            .font(TerminalFonts.bodyMono.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(viewModel.canSubmitRequest ? TerminalColors.primary : TerminalColors.textSecondary)
                .foregroundColor(.black)
            }
            .disabled(!viewModel.canSubmitRequest || viewModel.isSubmitting)
            
            // Messages
            if let error = viewModel.errorMessage {
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
            
            if let success = viewModel.successMessage {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
    
    // MARK: - Category Tags
    private var categoryTags: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AssetRequest.AssetCategory.allCases, id: \.self) { category in
                    Button(action: {
                        viewModel.selectCategory(category)
                    }) {
                        Text(category.displayName)
                            .font(TerminalFonts.caption2.weight(.bold))
                            .foregroundColor(viewModel.selectedCategory == category ? .black : Color(hex: category.color))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedCategory == category ? Color(hex: category.color) : TerminalColors.backgroundTertiary)
                            .border(Color(hex: category.color), width: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
    }
    
    // MARK: - Content Area
    private var contentArea: some View {
        Group {
            if showResults && viewModel.hasSearchResults {
                searchResultsList
            } else {
                myRequestsList
            }
        }
    }
    
    // MARK: - Search Results List
    private var searchResultsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SEARCH RESULTS")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TerminalColors.backgroundTertiary)
            
            List {
                ForEach(viewModel.searchResults, id: \.ticker) { result in
                    Button(action: {
                        viewModel.selectResult(result)
                        showResults = false
                    }) {
                        HStack {
                            Text(result.ticker)
                                .font(TerminalFonts.ticker)
                                .foregroundColor(TerminalColors.textPrimary)
                            
                            Spacer()
                            
                            Text(result.category.displayName)
                                .font(TerminalFonts.caption2)
                                .foregroundColor(Color(hex: result.category.color))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(TerminalColors.backgroundTertiary)
                                .border(Color(hex: result.category.color), width: 1)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(TerminalColors.backgroundSecondary)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(PlainListStyle())
            .background(TerminalColors.background)
        }
    }
    
    // MARK: - My Requests List
    private var myRequestsList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("MY REQUESTS")
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textSecondary)
                
                Spacer()
                
                Button(action: {
                    Task {
                        await viewModel.fetchUserRequests()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(TerminalColors.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(TerminalColors.backgroundTertiary)
            
            if viewModel.isLoadingRequests {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: TerminalColors.primary))
                    Spacer()
                }
                .padding(.vertical, 32)
            } else if viewModel.userRequests.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(TerminalColors.textTertiary)
                    
                    Text("NO REQUESTS")
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.textSecondary)
                    
                    Text("Search for a ticker above to request analysis")
                        .font(TerminalFonts.caption2)
                        .foregroundColor(TerminalColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 48)
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.userRequests) { request in
                        RequestRow(request: request)
                            .listRowBackground(TerminalColors.backgroundSecondary)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(PlainListStyle())
                .background(TerminalColors.background)
            }
        }
    }
}

// MARK: - Request Row
struct RequestRow: View {
    let request: AssetRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(request.displayTicker)
                    .font(TerminalFonts.ticker)
                    .foregroundColor(TerminalColors.textPrimary)
                
                Spacer()
                
                // Status Badge
                Text(request.status.displayName)
                    .font(TerminalFonts.caption2.weight(.bold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TerminalColors.backgroundTertiary)
                    .border(statusColor, width: 1)
            }
            
            HStack {
                Text(request.category.displayName)
                    .font(TerminalFonts.caption2)
                    .foregroundColor(Color(hex: request.category.color))
                
                Text("•")
                    .foregroundColor(TerminalColors.textTertiary)
                
                Text(request.formattedTimestamp)
                    .font(TerminalFonts.caption2)
                    .foregroundColor(TerminalColors.textSecondary)
            }
            
            if let description = request.description, !description.isEmpty {
                Text(description)
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }
    
    private var statusColor: Color {
        switch request.status {
        case .pending:
            return TerminalColors.warning
        case .fulfilled:
            return TerminalColors.positive
        case .rejected:
            return TerminalColors.negative
        }
    }
}

// MARK: - Preview
struct RequestMarketView_Previews: PreviewProvider {
    static var previews: some View {
        RequestMarketView()
            .preferredColorScheme(.dark)
    }
}
