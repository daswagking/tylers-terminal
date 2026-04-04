//
//  RequestMarketViewModel.swift
//  TYLER'S TERMINAL
//

import SwiftUI
import Combine

@MainActor
class RequestMarketViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var searchResults: [(ticker: String, category: AssetRequest.AssetCategory)] = []
    @Published var selectedCategory: AssetRequest.AssetCategory = .stock
    @Published var customDescription: String = ""
    @Published var isSearching = false
    @Published var isSubmitting = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var showCustomRequest = false
    
    @Published var userRequests: [AssetRequest] = []
    @Published var isLoadingRequests = false
    
    private var searchTask: Task<Void, Never>?
    
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
    
    func performSearch() {
        guard !searchQuery.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let results = AssetDatabase.search(query: searchQuery)
        searchResults = Array(results.prefix(10))
        
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
            
            await fetchUserRequests()
            
        } catch let error as SupabaseError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "SUBMISSION FAILED"
        }
        
        isSubmitting = false
    }
    
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
    
    func selectCategory(_ category: AssetRequest.AssetCategory) {
        selectedCategory = category
        if !searchQuery.isEmpty {
            performSearch()
        }
    }
    
    func getCategoryColor(for ticker: String) -> String {
        return AssetDatabase.category(for: ticker)?.color ?? "#888888"
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    func debouncedSearch() {
        searchTask?.cancel()
        
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                performSearch()
            }
        }
    }
}
