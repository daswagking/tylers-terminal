//
//  AuthViewModel.swift
//  TYLER'S TERMINAL
//

import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var state: AuthState = .unauthenticated
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    // MARK: - Computed Properties
    var isAuthenticated: Bool {
        if case .authenticated = state {
            return true
        }
        return false
    }
    
    var currentUser: User? {
        if case .authenticated(let user) = state {
            return user
        }
        return nil
    }
    
    // MARK: - Validation
    var canSignIn: Bool {
        return !username.isEmpty && password.count >= 6
    }
    
    var canSignUp: Bool {
        return !username.isEmpty &&
               username.count >= 3 &&
               password.count >= 6 &&
               password == confirmPassword
    }
    
    var validationError: String? {
        if username.isEmpty {
            return "USERNAME REQUIRED"
        }
        if username.count < 3 {
            return "USERNAME MIN 3 CHARS"
        }
        if password.isEmpty {
            return "PASSWORD REQUIRED"
        }
        if password.count < 6 {
            return "PASSWORD MIN 6 CHARS"
        }
        if !confirmPassword.isEmpty && password != confirmPassword {
            return "PASSWORDS DO NOT MATCH"
        }
        return nil
    }
    
    // MARK: - Initialization
    init() {
        checkSession()
    }
    
    // MARK: - Session Management
    private func checkSession() {
        if let savedUsername = UserDefaults.standard.string(forKey: "savedUsername"),
           let savedUserId = UserDefaults.standard.string(forKey: "savedUserId") {
            let isAdmin = UserDefaults.standard.bool(forKey: "isAdmin")
            let user = User(
                id: savedUserId,
                username: savedUsername,
                isAdmin: isAdmin
            )
            state = .authenticated(user)
        }
    }
    
    // MARK: - Sign In
    func signIn() async {
        // HARDCODED ADMIN BYPASS
        if username.lowercased() == "admin" && password == "admin123" {
            let adminUser = User(
                id: "admin-001",
                username: "ADMIN",
                isAdmin: true
            )
            saveSession(user: adminUser, token: "admin-token")
            state = .authenticated(adminUser)
            clearFields()
            return
        }
        
        guard canSignIn else {
            errorMessage = validationError
            return
        }
        
        isLoading = true
        errorMessage = nil
        state = .authenticating
        
        do {
            let (user, token) = try await SupabaseService.shared.signIn(
                username: username.trimmingCharacters(in: .whitespaces),
                password: password
            )
            
            // Check if user is admin in database
            let adminStatus = await checkAdminStatus(userId: user.id)
            let updatedUser = User(
                id: user.id,
                username: user.username,
                isAdmin: adminStatus
            )
            
            saveSession(user: updatedUser, token: token)
            state = .authenticated(updatedUser)
            clearFields()
            
        } catch let error as SupabaseError {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        } catch {
            state = .error("CONNECTION LOST")
            errorMessage = "CONNECTION LOST"
        }
        
        isLoading = false
    }
    
    // MARK: - Check Admin Status
    private func checkAdminStatus(userId: String) async -> Bool {
        // Hardcoded admin IDs
        let adminIds = ["admin-001", "550e8400-e29b-41d4-a716-446655440000"]
        if adminIds.contains(userId) {
            return true
        }
        
        // Check database
        do {
            let users = try await SupabaseService.shared.fetchAllUsers()
            if let user = users.first(where: { $0.id == userId }) {
                return user.isAdmin
            }
        } catch {
            print("Failed to check admin status: \(error)")
        }
        return false
    }
    
    // MARK: - Sign Up
    func signUp() async {
        guard canSignUp else {
            errorMessage = validationError
            return
        }
        
        isLoading = true
        errorMessage = nil
        state = .authenticating
        
        do {
            let user = try await SupabaseService.shared.signUp(
                username: username.trimmingCharacters(in: .whitespaces).lowercased(),
                password: password
            )
            
            saveSession(user: user)
            state = .authenticated(user)
            clearFields()
            
        } catch let error as SupabaseError {
            state = .error(error.localizedDescription)
            errorMessage = error.localizedDescription
        } catch {
            state = .error("REGISTRATION FAILED")
            errorMessage = "REGISTRATION FAILED"
        }
        
        isLoading = false
    }
    
    // MARK: - Sign Out
    func signOut() async {
        isLoading = true
        
        do {
            try await SupabaseService.shared.signOut()
            clearSession()
            state = .unauthenticated
        } catch {
            errorMessage = "SIGN OUT FAILED"
        }
        
        isLoading = false
    }
    
    // MARK: - Helper Methods
    private func saveSession(user: User) {
        UserDefaults.standard.set(user.username, forKey: "savedUsername")
        UserDefaults.standard.set(user.id, forKey: "savedUserId")
        UserDefaults.standard.set(user.isAdmin, forKey: "isAdmin")
        UserDefaults.standard.set(token, forKey: "authToken")
    }
    
    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: "savedUsername")
        UserDefaults.standard.removeObject(forKey: "savedUserId")
        UserDefaults.standard.removeObject(forKey: "isAdmin")
        username = ""
        password = ""
        confirmPassword = ""
    }
    
    private func clearFields() {
        username = ""
        password = ""
        confirmPassword = ""
        errorMessage = nil
    }
    
    func clearError() {
        errorMessage = nil
        if case .error = state {
            state = .unauthenticated
        }
    }
}
