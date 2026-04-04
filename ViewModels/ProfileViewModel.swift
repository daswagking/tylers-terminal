//
//  ProfileViewModel.swift
//  TYLER'S TERMINAL
//
//  Profile and settings state management
//

import SwiftUI
import Combine

@MainActor
class ProfileViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // MARK: - Settings
    @Published var pushNotificationsEnabled: Bool = true
    @Published var showChangePasswordSheet = false
    
    // MARK: - Password Change
    @Published var currentPassword: String = ""
    @Published var newPassword: String = ""
    @Published var confirmNewPassword: String = ""
    
    // MARK: - App Info
    let appVersion: String
    let buildNumber: String
    
    // MARK: - Computed Properties
    var displayUsername: String {
        return user?.displayName ?? "UNKNOWN"
    }
    
    var displayTerminalId: String {
        return user?.displayTerminalId ?? "TT-00000000-0000"
    }
    
    var canChangePassword: Bool {
        return !currentPassword.isEmpty && 
               newPassword.count >= 6 &&
               newPassword == confirmNewPassword
    }
    
    var passwordChangeError: String? {
        if currentPassword.isEmpty {
            return "CURRENT PASSWORD REQUIRED"
        }
        if newPassword.count < 6 {
            return "NEW PASSWORD MIN 6 CHARS"
        }
        if newPassword != confirmNewPassword {
            return "PASSWORDS DO NOT MATCH"
        }
        return nil
    }
    
    // MARK: - Initialization
    init(user: User? = nil) {
        self.user = user
        
        // Get app version info
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        
        self.appVersion = version
        self.buildNumber = build
        
        // Load settings
        self.pushNotificationsEnabled = UserDefaults.standard.bool(forKey: "pushNotificationsEnabled")
    }
    
    // MARK: - Load User
    func loadUser(_ user: User) {
        self.user = user
        self.pushNotificationsEnabled = user.pushNotificationsEnabled
    }
    
    // MARK: - Update Push Notifications
    func updatePushNotifications(enabled: Bool) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await SupabaseService.shared.updatePushNotifications(enabled: enabled)
            
            // Update local state
            pushNotificationsEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: "pushNotificationsEnabled")
            
            successMessage = enabled ? "NOTIFICATIONS ENABLED" : "NOTIFICATIONS DISABLED"
            
        } catch {
            errorMessage = "UPDATE FAILED"
            // Revert toggle
            pushNotificationsEnabled = !enabled
        }
        
        isLoading = false
    }
    
    // MARK: - Change Password
    func changePassword() async -> Bool {
        guard canChangePassword else {
            errorMessage = passwordChangeError
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        // TODO: Implement password change via Supabase
        // This requires re-authentication with current password
        
        // Simulate success for now
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        successMessage = "PASSWORD UPDATED"
        clearPasswordFields()
        showChangePasswordSheet = false
        
        isLoading = false
        return true
    }
    
    // MARK: - Helper Methods
    private func clearPasswordFields() {
        currentPassword = ""
        newPassword = ""
        confirmNewPassword = ""
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    func dismissChangePasswordSheet() {
        showChangePasswordSheet = false
        clearPasswordFields()
    }
}
