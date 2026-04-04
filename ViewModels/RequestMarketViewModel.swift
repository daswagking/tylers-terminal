//
//  RequestMarketViewModel.swift
//  TYLER'S TERMINAL
//
//  Request Market state management
//

import SwiftUI
import Combine

@MainActor
class RequestMarketViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var searchQuery: String = ""
    @Published var searchResults: [(ticker: String, category: AssetRequest.AssetCategory)] = []
    @Published var selectedCategory: AssetRequest.AssetCategory = .stock
    @Published var customDescription: String = ""
    @Published var isSearching = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showCustomRequest = false
    
    private var searchTask: Task<Void, Never>?
    
    // MARK: - User Requests
    @Published var userRequests: [AssetRequest] = []
    @Published var isLoadingRequests = false
    
    // MARK: - Computed Properties
    var hasSearchResults: Bool {
        return !searchResults.isEmpty
    }
    
    var canSubmitRequest: Bool {
        if showCustomRequest {
            return !searchQuery.isEmpty && searchQuery.count >= 2
        }
        return !searchQuery.isEmpty
    }
    
    var displaySearchQuery: String {
        return searchQuery.uppercased()
    }
    
    // MARK: - Search
    func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // Search in preloaded database
        let results = AssetDatabase.search(query: searchQuery)
        searchResults = Array(results.prefix(10)) // Limit to 10 results
        
        isSearching = false
    }
    
    func clearSearch() {
        searchQuery = ""
        searchResults = []
        showCustomRequest = false
        customDescription = ""
    }
    
    func selectResult(_ result: (ticker: String, category: AssetRequest.AssetCategory)) {
        searchQuery = result.ticker
        selectedCategory = result.category
        searchResults = []
    }
    
    // MARK: - Submit Request
    func submitRequest() async {
        guard canSubmitRequest else {
            errorMessage = "INVALID REQUEST"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        successMessage = nil
        
        let ticker = searchQuery.uppercased().trimmingCharacters(in: .whitespaces)
        let category = showCustomRequest ? AssetRequest.AssetCategory.custom : selectedCategory
        let description = showCustomRequest ? customDescription : nil
        
        do {
            try await SupabaseService.shared.submitAssetRequest(
                ticker: ticker,
                category: category,
                description: description
            )
            
            successMessage = "REQUEST SUBMITTED: \(ticker)"
            clearSearch()
            
            // Refresh user requests
            await fetchUserRequests()
            
        } catch let error as SupabaseError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "SUBMISSION FAILED"
        }
        
        isSubmitting = false
    }
    
    // MARK: - Fetch User Requests
    func fetchUserRequests() async {
        isLoadingRequests = true
        
        do {
            let requests = try await SupabaseService.shared.fetchUserRequests()
            userRequests = requests
        } catch {
            errorMessage = "FAILED TO LOAD REQUESTS"
        }
        
        isLoadingRequests = false
    }
    
    // MARK: - Category Selection
    func selectCategory(_ category: AssetRequest.AssetCategory) {
        selectedCategory = category
        // Filter search results by category
        if !searchQuery.isEmpty {
            performSearch()
        }
    }
    
    // MARK: - Helper Methods
    func getCategoryColor(for ticker: String) -> String {
        return AssetDatabase.category(for: ticker).color
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}

// MARK: - Debounced Search
extension RequestMarketViewModel {
    func debouncedSearch() {
        // Cancel previous search task
        searchTask?.cancel()
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                performSearch()
            }
        }
    }
    

}
