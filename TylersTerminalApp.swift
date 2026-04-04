//
//  TylersTerminalApp.swift
//  TYLER'S TERMINAL
//
//  Production-ready trading journal app with Bloomberg Terminal aesthetic
//  iOS 17+ | SwiftUI | Supabase | Firebase
//

import SwiftUI
import FirebaseCore
import FirebaseMessaging

@main
struct TylersTerminalApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var feedViewModel = FeedViewModel()
    @StateObject private var activityViewModel = ActivityViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(feedViewModel)
                .environmentObject(activityViewModel)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

// MARK: - Main Tab View
struct MainTabView: View {
    @EnvironmentObject var activityViewModel: ActivityViewModel
    
    var body: some View {
        TabView {
            FeedView()
                .tabItem {
                    Image(systemName: "terminal")
                    Text("FEED")
                }
            
            RequestMarketView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("REQUEST")
                }
            
            ActivityView()
                .tabItem {
                    Image(systemName: "bell")
                    Text("ACTIVITY")
                }
                .badge(activityViewModel.unreadCount > 0 ? activityViewModel.unreadCount : 0)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person")
                    Text("PROFILE")
                }
        }
        .accentColor(TerminalColors.primary)
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(TerminalColors.background)
            
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor(TerminalColors.textSecondary)
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(TerminalColors.textSecondary)]
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(TerminalColors.primary)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(TerminalColors.primary)]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}
