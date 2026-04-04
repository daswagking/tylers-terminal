//
//  AppDelegate.swift
//  TYLER'S TERMINAL
//
//  Firebase and Push Notification Configuration
//

import UIKit
import SwiftUI
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate {
    
    let gcmMessageIDKey = "gcm.message_id"
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Messaging delegate
        Messaging.messaging().delegate = self
        
        // Configure Notification Center delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions
        requestNotificationPermissions(application)
        
        // Register for remote notifications
        application.registerForRemoteNotifications()
        
        // Configure navigation bar appearance
        configureNavigationBar()
        
        return true
    }
    
    // MARK: - Notification Permissions
    private func requestNotificationPermissions(_ application: UIApplication) {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: { granted, error in
                if let error = error {
                    print("[TERMINAL] Notification permission error: \(error)")
                } else {
                    print("[TERMINAL] Notification permission granted: \(granted)")
                }
            }
        )
    }
    
    // MARK: - Navigation Bar Configuration
    private func configureNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.black
        appearance.titleTextAttributes = [
            .foregroundColor: TerminalColors.primary.uiColor,
            .font: UIFont.monospacedSystemFont(ofSize: 18, weight: .bold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: TerminalColors.primary.uiColor,
            .font: UIFont.monospacedSystemFont(ofSize: 32, weight: .bold)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // MARK: - APNs Registration
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Set APNs token for Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        
        // Log token for debugging (remove in production)
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[TERMINAL] APNs Device Token: \(tokenString)")
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[TERMINAL] Failed to register for remote notifications: \(error)")
    }
    
    // MARK: - Background Fetch
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if let messageID = userInfo[gcmMessageIDKey] {
            print("[TERMINAL] Message ID: \(messageID)")
        }
        
        print("[TERMINAL] Remote notification received: \(userInfo)")
        
        // Handle the notification data
        NotificationCenter.default.post(
            name: Notification.Name("NewTradeNotification"),
            object: nil,
            userInfo: userInfo
        )
        
        completionHandler(.newData)
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("[TERMINAL] Message ID from userNotificationCenter: \(messageID)")
        }
        
        print("[TERMINAL] Notification received in foreground: \(userInfo)")
        
        // Post notification to update UI
        NotificationCenter.default.post(
            name: Notification.Name("NewTradeNotification"),
            object: nil,
            userInfo: userInfo
        )
        
        // Show notification even when app is in foreground
        completionHandler([[.banner, .sound, .badge]])
    }
    
    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let messageID = userInfo[gcmMessageIDKey] {
            print("[TERMINAL] Message ID from notification tap: \(messageID)")
        }
        
        print("[TERMINAL] Notification tapped: \(userInfo)")
        
        // Handle navigation based on notification type
        if let type = userInfo["type"] as? String {
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToNotification"),
                object: nil,
                userInfo: ["type": type, "postId": userInfo["post_id"] as? String]
            )
        }
        
        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    
    func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        print("[TERMINAL] Firebase registration token: \(String(describing: fcmToken))")
        
        // Store FCM token in UserDefaults
        if let token = fcmToken {
            UserDefaults.standard.set(token, forKey: "fcmToken")
            
            // TODO: Send token to Supabase to store for this user
            // This would be called after user authentication
            Task {
                await updateFCMToken(token)
            }
        }
        
        let dataDict: [String: String] = ["token": fcmToken ?? ""]
        NotificationCenter.default.post(
            name: Notification.Name("FCMToken"),
            object: nil,
            userInfo: dataDict
        )
    }
    
    private func updateFCMToken(_ token: String) async {
        // This function would update the FCM token in Supabase
        // Implementation depends on user authentication state
        print("[TERMINAL] Updating FCM token in database: \(token)")
    }
}

// MARK: - Scene Lifecycle (for iOS 13+)
extension AppDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let sceneConfig = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        sceneConfig.delegateClass = SceneDelegate.self
        return sceneConfig
    }
}

// MARK: - SceneDelegate
class SceneDelegate: NSObject, UIWindowSceneDelegate {
    
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Handle URL contexts (deep links)
        if let urlContext = connectionOptions.urlContexts.first {
            handleDeepLink(url: urlContext.url)
        }
    }
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        if let url = URLContexts.first?.url {
            handleDeepLink(url: url)
        }
    }
    
    private func handleDeepLink(url: URL) {
        print("[TERMINAL] Deep link received: \(url)")
        
        // Handle deep links like tylersterminal://post/123
        if url.scheme == "tylersterminal" {
            let path = url.pathComponents
            if path.count > 2 && path[1] == "post" {
                let postId = path[2]
                NotificationCenter.default.post(
                    name: Notification.Name("NavigateToPost"),
                    object: nil,
                    userInfo: ["postId": postId]
                )
            }
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Reset badge count when app becomes active
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    func sceneDidEnterBackground(_ scene: UIScene) {
        // Clean up realtime subscriptions
        NotificationCenter.default.post(
            name: Notification.Name("AppDidEnterBackground"),
            object: nil
        )
    }
    
    func sceneWillEnterForeground(_ scene: UIScene) {
        // Reconnect realtime subscriptions
        NotificationCenter.default.post(
            name: Notification.Name("AppWillEnterForeground"),
            object: nil
        )
    }
}
