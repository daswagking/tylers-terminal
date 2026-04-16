//
//  AuthViewModel.swift
//  TYLER'S TERMINAL
//
//  Authentication state management
//

import SwiftUI
import Combine

// MARK: - Auth State Enum
enum AuthState {
    case unauthenticated
    case authenticating
    case authenticated(User)
    case error(String)
}

@MainActor
class AuthViewModel: ObservableObject {
    
    @Published var state: AuthState = .unauthenticated
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var errorMessage: String?
    @Published var isLoading = false
    
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
    
    init() {
        checkSession()
    }
    
    private func checkSession() {
        if let savedUsername = UserDefaults.standard.string(forKey: "savedUsername"),
           let savedUserId = UserDefaults.standard.string(forKey: "savedUserId") {
            let email = "\(savedUsername.lowercased())@tylersterminal.local"
            let isAdmin = UserDefaults.standard.bool(forKey: "savedIsAdmin")
            let user = User(
                id: savedUserId,
                username: savedUsername,
                email: email,
                isAdmin: isAdmin
            )
            SupabaseService.shared.setCurrentUser(id: savedUserId, username: savedUsername)
            state = .authenticated(user)
        }
    }
    
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
    
    func signUp() async {
        guard canSignUp else {
            errorMessage = validationError ?? "INVALID INPUT"
            return
        }
        
        isLoading = true
        errorMessage = nil
        state = .authenticating
        
        do {
            let user = try await SupabaseService.shared.signUp(
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
            state = .error("REGISTRATION FAILED")
            errorMessage = "REGISTRATION FAILED"
        }
        
        isLoading = false
    }
    
    func signOut() {
        UserDefaults.standard.removeObject(forKey: "savedUsername")
        UserDefaults.standard.removeObject(forKey: "savedUserId")
        UserDefaults.standard.removeObject(forKey: "savedIsAdmin")
        SupabaseService.shared.signOut()
        state = .unauthenticated
        clearFields()
    }

    private func saveSession(user: User) {
        UserDefaults.standard.set(user.username, forKey: "savedUsername")
        UserDefaults.standard.set(user.id, forKey: "savedUserId")
        UserDefaults.standard.set(user.isAdmin, forKey: "savedIsAdmin")
    }
    
    private func clearFields() {
        username = ""
        password = ""
        confirmPassword = ""
    }
    
    func clearError() {
        errorMessage = nil
        if case .error = state {
            state = .unauthenticated
        }
    }
}
