//
//  LoginView.swift
//  TYLER'S TERMINAL
//
//  Login and Registration screen
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isSignUp = false
    
    var body: some View {
        ZStack {
            TerminalColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Logo Section
                logoSection
                
                // Form Section
                formSection
                
                Spacer()
                
                // Toggle Sign In/Sign Up
                toggleSection
            }
        }
    }
    
    // MARK: - Logo Section
    private var logoSection: some View {
        VStack(spacing: 16) {
            // Terminal Icon
            ZStack {
                Rectangle()
                    .fill(TerminalColors.backgroundSecondary)
                    .frame(width: 80, height: 80)
                    .border(TerminalColors.primary, width: 2)
                
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(TerminalColors.primary)
                        .frame(width: 40, height: 4)
                    Rectangle()
                        .fill(TerminalColors.primary)
                        .frame(width: 40, height: 4)
                    Rectangle()
                        .fill(TerminalColors.primary)
                        .frame(width: 40, height: 4)
                }
            }
            
            Text("TYLER'S TERMINAL")
                .font(TerminalFonts.header)
                .foregroundColor(TerminalColors.primary)
            
            Text(isSignUp ? "CREATE ACCOUNT" : "SIGN IN")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(.top, 60)
        .padding(.bottom, 40)
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: 20) {
            // Error Message
            if let error = authViewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(TerminalColors.alert)
                    Text(error)
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.alert)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(TerminalColors.backgroundSecondary)
                .border(TerminalColors.alert, width: 1)
            }
            
            // Username Field
            VStack(alignment: .leading, spacing: 8) {
                Text("USERNAME")
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textSecondary)
                
                TextField("", text: $authViewModel.username)
                    .font(TerminalFonts.bodyMono)
                    .foregroundColor(TerminalColors.textPrimary)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(TerminalColors.backgroundTertiary)
                    .border(TerminalColors.border, width: 1)
            }
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("PASSWORD")
                    .font(TerminalFonts.caption)
                    .foregroundColor(TerminalColors.textSecondary)
                
                SecureField("", text: $authViewModel.password)
                    .font(TerminalFonts.bodyMono)
                    .foregroundColor(TerminalColors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(TerminalColors.backgroundTertiary)
                    .border(TerminalColors.border, width: 1)
            }
            
            // Confirm Password (Sign Up only)
            if isSignUp {
                VStack(alignment: .leading, spacing: 8) {
                    Text("CONFIRM PASSWORD")
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.textSecondary)
                    
                    SecureField("", text: $authViewModel.confirmPassword)
                        .font(TerminalFonts.bodyMono)
                        .foregroundColor(TerminalColors.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 14)
                        .background(TerminalColors.backgroundTertiary)
                        .border(TerminalColors.border, width: 1)
                }
            }
            
            // Submit Button
            Button(action: submitAction) {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                    } else {
                        Text(isSignUp ? "CREATE ACCOUNT" : "SIGN IN")
                            .font(TerminalFonts.bodyMono.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isSubmitEnabled ? TerminalColors.primary : TerminalColors.textSecondary)
                .foregroundColor(.black)
            }
            .disabled(!isSubmitEnabled || authViewModel.isLoading)
            .padding(.top, 10)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Toggle Section
    private var toggleSection: some View {
        HStack(spacing: 4) {
            Text(isSignUp ? "ALREADY HAVE AN ACCOUNT?" : "NEW USER?")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
            
            Button(action: {
                isSignUp.toggle()
                authViewModel.clearError()
            }) {
                Text(isSignUp ? "SIGN IN" : "CREATE ACCOUNT")
                    .font(TerminalFonts.caption.weight(.bold))
                    .foregroundColor(TerminalColors.primary)
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Computed Properties
    private var isSubmitEnabled: Bool {
        if isSignUp {
            return authViewModel.canSignUp
        } else {
            return authViewModel.canSignIn
        }
    }
    
    // MARK: - Actions
    private func submitAction() {
        Task {
            if isSignUp {
                await authViewModel.signUp()
            } else {
                await authViewModel.signIn()
            }
        }
    }
}

// MARK: - Preview
struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
            .preferredColorScheme(.dark)
    }
}
