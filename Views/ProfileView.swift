//
//  ProfileView.swift
//  TYLER'S TERMINAL
//
//  Profile and settings screen
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showSignOutConfirmation = false
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Profile Header
                        profileHeader
                        
                        // Settings Section
                        settingsSection
                        
                        // App Info Section
                        appInfoSection
                        
                        // Sign Out Button
                        signOutButton
                    }
                }
            }
            .navigationTitle("PROFILE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "person")
                            .foregroundColor(TerminalColors.primary)
                        Text("PROFILE")
                            .font(TerminalFonts.header3)
                            .foregroundColor(TerminalColors.primary)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            if let user = authViewModel.currentUser {
                viewModel.loadUser(user)
            }
        }
        .sheet(isPresented: $viewModel.showChangePasswordSheet) {
            ChangePasswordSheet(viewModel: viewModel)
        }
        .alert("SIGN OUT", isPresented: $showSignOutConfirmation) {
            Button("CANCEL", role: .cancel) {}
            Button("SIGN OUT", role: .destructive) {
                Task {
                    await authViewModel.signOut()
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    // MARK: - Profile Header
    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Rectangle()
                    .fill(TerminalColors.backgroundTertiary)
                    .frame(width: 100, height: 100)
                    .border(TerminalColors.primary, width: 2)
                
                VStack(spacing: 4) {
                    Text(viewModel.displayUsername.prefix(2).uppercased())
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundColor(TerminalColors.primary)
                }
            }
            .padding(.top, 24)
            
            // Username
            Text(viewModel.displayUsername)
                .font(TerminalFonts.header)
                .foregroundColor(TerminalColors.primary)
            
            // Terminal ID
            HStack(spacing: 8) {
                Text("TERMINAL ID:")
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textSecondary)
                Text(viewModel.displayTerminalId)
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(TerminalColors.backgroundTertiary)
            .border(TerminalColors.border, width: 1)
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Settings Section
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SETTINGS")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TerminalColors.backgroundTertiary)
            
            VStack(spacing: 0) {
                // Push Notifications Toggle
                HStack {
                    Image(systemName: "bell.badge")
                        .font(.system(size: 18))
                        .foregroundColor(TerminalColors.primary)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PUSH NOTIFICATIONS")
                            .font(TerminalFonts.body.weight(.medium))
                            .foregroundColor(TerminalColors.textPrimary)
                        Text("Receive alerts for new trades")
                            .font(TerminalFonts.caption2)
                            .foregroundColor(TerminalColors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $viewModel.pushNotificationsEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: TerminalColors.primary))
                        .onChange(of: viewModel.pushNotificationsEnabled) { newValue in
                            Task {
                                await viewModel.updatePushNotifications(enabled: newValue)
                            }
                        }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(TerminalColors.backgroundSecondary)
                
                Divider()
                    .background(TerminalColors.border)
                
                // Change Password Button
                Button(action: {
                    viewModel.showChangePasswordSheet = true
                }) {
                    HStack {
                        Image(systemName: "lock")
                            .font(.system(size: 18))
                            .foregroundColor(TerminalColors.primary)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("CHANGE PASSWORD")
                                .font(TerminalFonts.body.weight(.medium))
                                .foregroundColor(TerminalColors.textPrimary)
                            Text("Update your account password")
                                .font(TerminalFonts.caption2)
                                .foregroundColor(TerminalColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(TerminalColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(TerminalColors.backgroundSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - App Info Section
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TERMINAL INFO")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TerminalColors.backgroundTertiary)
            
            VStack(spacing: 0) {
                // Version
                HStack {
                    Text("VERSION")
                        .font(TerminalFonts.body)
                        .foregroundColor(TerminalColors.textPrimary)
                    
                    Spacer()
                    
                    Text("\(viewModel.appVersion) (\(viewModel.buildNumber))")
                        .font(TerminalFonts.bodyMono)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(TerminalColors.backgroundSecondary)
                
                Divider()
                    .background(TerminalColors.border)
                
                // Platform
                HStack {
                    Text("PLATFORM")
                        .font(TerminalFonts.body)
                        .foregroundColor(TerminalColors.textPrimary)
                    
                    Spacer()
                    
                    Text("iOS 17+")
                        .font(TerminalFonts.bodyMono)
                        .foregroundColor(TerminalColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(TerminalColors.backgroundSecondary)
                
                Divider()
                    .background(TerminalColors.border)
                
                // Backend
                HStack {
                    Text("BACKEND")
                        .font(TerminalFonts.body)
                        .foregroundColor(TerminalColors.textPrimary)
                    
                    Spacer()
                    
                    Text("SUPABASE")
                        .font(TerminalFonts.bodyMono)
                        .foregroundColor(TerminalColors.positive)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(TerminalColors.backgroundSecondary)
            }
        }
        .padding(.top, 24)
    }
    
    // MARK: - Sign Out Button
    private var signOutButton: some View {
        Button(action: {
            showSignOutConfirmation = true
        }) {
            HStack {
                Image(systemName: "arrow.right.square")
                    .font(.system(size: 18))
                Text("SIGN OUT")
                    .font(TerminalFonts.bodyMono.weight(.bold))
            }
            .foregroundColor(TerminalColors.negative)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(TerminalColors.backgroundSecondary)
            .border(TerminalColors.negative, width: 1)
        }
        .padding(.horizontal, 16)
        .padding(.top, 32)
        .padding(.bottom, 24)
    }
}

// MARK: - Change Password Sheet
struct ChangePasswordSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Error/Success Messages
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
                    
                    // Form Fields
                    VStack(alignment: .leading, spacing: 16) {
                        // Current Password
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CURRENT PASSWORD")
                                .font(TerminalFonts.caption)
                                .foregroundColor(TerminalColors.textSecondary)
                            
                            SecureField("", text: $viewModel.currentPassword)
                                .font(TerminalFonts.bodyMono)
                                .foregroundColor(TerminalColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(TerminalColors.backgroundTertiary)
                                .border(TerminalColors.border, width: 1)
                        }
                        
                        // New Password
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NEW PASSWORD")
                                .font(TerminalFonts.caption)
                                .foregroundColor(TerminalColors.textSecondary)
                            
                            SecureField("", text: $viewModel.newPassword)
                                .font(TerminalFonts.bodyMono)
                                .foregroundColor(TerminalColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(TerminalColors.backgroundTertiary)
                                .border(TerminalColors.border, width: 1)
                        }
                        
                        // Confirm New Password
                        VStack(alignment: .leading, spacing: 4) {
                            Text("CONFIRM NEW PASSWORD")
                                .font(TerminalFonts.caption)
                                .foregroundColor(TerminalColors.textSecondary)
                            
                            SecureField("", text: $viewModel.confirmNewPassword)
                                .font(TerminalFonts.bodyMono)
                                .foregroundColor(TerminalColors.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .background(TerminalColors.backgroundTertiary)
                                .border(TerminalColors.border, width: 1)
                        }
                    }
                    
                    Spacer()
                    
                    // Update Button
                    Button(action: {
                        Task {
                            let success = await viewModel.changePassword()
                            if success {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                    presentationMode.wrappedValue.dismiss()
                                }
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    .scaleEffect(0.8)
                            } else {
                                Text("UPDATE PASSWORD")
                                    .font(TerminalFonts.bodyMono.weight(.bold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(viewModel.canChangePassword ? TerminalColors.primary : TerminalColors.textSecondary)
                        .foregroundColor(.black)
                    }
                    .disabled(!viewModel.canChangePassword || viewModel.isLoading)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
            }
            .navigationTitle("CHANGE PASSWORD")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("CANCEL") {
                        viewModel.dismissChangePasswordSheet()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.textSecondary)
                }
            }
        }
    }
}

// MARK: - Preview
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
    }
}
