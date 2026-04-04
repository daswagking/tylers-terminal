//
//  ActivityViewModel.swift
//  TYLER'S TERMINAL
//

import SwiftUI
import Combine

@MainActor
class ActivityViewModel: ObservableObject {
    
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: NotificationFilter = .all
    
    enum NotificationFilter: String, CaseIterable {
        case all = "ALL"
        case unread = "UNREAD"
        case trades = "TRADES"
        case comments = "COMMENTS"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    var unreadCount: Int {
        return notifications.filter { !$0.isRead }.count
    }
    
    var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all:
            return notifications
        case .unread:
            return notifications.filter { !$0.isRead }
        case .trades:
            return notifications.filter {
                $0.type == .newPost || $0.type == .system
            }
        case .comments:
            return notifications.filter {
                $0.type == .newComment || $0.type == .reaction
            }
        }
    }
    
    var hasUnreadNotifications: Bool {
        return unreadCount > 0
    }
    
    init() {}
    
    func fetchNotifications() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newNotifications = try await SupabaseService.shared.fetchNotifications()
            notifications = newNotifications
        } catch {
            errorMessage = "CONNECTION LOST"
        }
        
        isLoading = false
    }
    
    func markAsRead(notificationId: String) async {
        do {
            try await SupabaseService.shared.markNotificationAsRead(notificationId: notificationId)
            
            if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
                notifications[index].isRead = true
            }
        } catch {
            errorMessage = "UPDATE FAILED"
        }
    }
    
    func markAllAsRead() async {
        let unreadNotifications = notifications.filter { !$0.isRead }
        
        for notification in unreadNotifications {
            await markAsRead(notificationId: notification.id)
        }
    }
    
    func deleteNotification(notificationId: String) {
        notifications.removeAll { $0.id == notificationId }
    }
    
    func setFilter(_ filter: NotificationFilter) {
        selectedFilter = filter
    }
    
    func clearError() {
        errorMessage = nil
    }
}
