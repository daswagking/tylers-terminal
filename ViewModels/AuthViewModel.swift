//
//  AuthViewModel.swift
//  TYLER'S TERMINAL
//
//  Authentication state management
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
            let user = User(
                id: savedUserId,
                username: savedUsername,
                pushNotificationsEnabled: UserDefaults.standard.bool(forKey: "pushNotificationsEnabled")
            )
            state = .authenticated(user)
        }
    }
    
    // MARK: - Sign In
    func signIn() async {
        guard canSignIn else {
            errorMessage = validationError
            return
        }
        
        isLoading = true
        errorMessage = nil
        state = .authenticating
        
        do {
            let user = try await SupabaseService.shared.signIn(
                username: username.trimmingCharacters(in: .whitespaces),
                password: password
            )
            
            saveSession(user: user)
            state = .authenticated(user)
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
    
    // MARK: - Change Password
    func changePassword(currentPassword: String, newPassword: String) async -> Bool {
        guard newPassword.count >= 6 else {
            errorMessage = "PASSWORD MIN 6 CHARS"
            return false
        }
        
        isLoading = true
        isLoading = false
        return true
    }
    
    // MARK: - Helper Methods
    private func saveSession(user: User) {
        UserDefaults.standard.set(user.username, forKey: "savedUsername")
        UserDefaults.standard.set(user.id, forKey: "savedUserId")
        UserDefaults.standard.set(user.pushNotificationsEnabled, forKey: "pushNotificationsEnabled")
    }
    
    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: "savedUsername")
        UserDefaults.standard.removeObject(forKey: "savedUserId")
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
