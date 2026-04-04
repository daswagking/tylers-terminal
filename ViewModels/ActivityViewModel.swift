//
//  ActivityViewModel.swift
//  TYLER'S TERMINAL
//
//  Activity/Notifications state management
//

import SwiftUI
import Combine

@MainActor
class ActivityViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedFilter: NotificationFilter = .all
    
    // MARK: - Filter Options
    enum NotificationFilter: String, CaseIterable {
        case all = "ALL"
        case unread = "UNREAD"
        case trades = "TRADES"
        case comments = "COMMENTS"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    // MARK: - Computed Properties
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
                $0.type == .newTrade || $0.type == .requestFulfilled 
            }
        case .comments:
            return notifications.filter { 
                $0.type == .commentOnPost || $0.type == .reactionReceived 
            }
        }
    }
    
    var hasUnreadNotifications: Bool {
        return unreadCount > 0
    }
    
    // MARK: - Initialization
    init() {
        setupNotifications()
    }
    
    // MARK: - Notification Setup
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleNewNotification),
            name: Notification.Name("NewTradeNotification"),
            object: nil
        )
    }
    
    @objc private func handleNewNotification(_ notification: Notification) {
        // Add new notification to list
        Task {
            await fetchNotifications()
        }
    }
    
    // MARK: - Fetch Notifications
    func fetchNotifications() async {
        guard !isLoading else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newNotifications = try await SupabaseService.shared.fetchNotifications()
            notifications = newNotifications
        } catch let error as SupabaseError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "CONNECTION LOST"
        }
        
        isLoading = false
    }
    
    // MARK: - Mark as Read
    func markAsRead(notificationId: UUID) async {
        do {
            try await SupabaseService.shared.markNotificationAsRead(notificationId: notificationId)
            
            // Update local state
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
    
    // MARK: - Delete Notification
    func deleteNotification(notificationId: UUID) {
        // Remove from local array
        notifications.removeAll { $0.id == notificationId }
        
        // TODO: Implement delete in Supabase
    }
    
    // MARK: - Filter
    func setFilter(_ filter: NotificationFilter) {
        selectedFilter = filter
    }
    
    // MARK: - Helper Methods
    func notifications(of type: AppNotification.NotificationType) -> [AppNotification] {
        return notifications.filter { $0.type == type }
    }
    
    func clearError() {
        errorMessage = nil
    }
}
