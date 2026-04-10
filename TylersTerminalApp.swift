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
    @StateObject private var requestMarketViewModel = RequestMarketViewModel()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(feedViewModel)
                .environmentObject(activityViewModel)
                .environmentObject(requestMarketViewModel)
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
                    Image(systemName: "bell.fill")
                    Text("ACTIVITY")
                }
                .badge(activityViewModel.unreadCount)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("PROFILE")
                }
        }
        .accentColor(TerminalColors.primary)
    }
}
