//
//  ActivityView.swift
//  TYLER'S TERMINAL
//

import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var viewModel: ActivityViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                TerminalColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    statusBar
                    filterBar
                    notificationsList
                }
            }
            .navigationTitle("ACTIVITY")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "bell")
                            .foregroundColor(TerminalColors.primary)
                        Text("ACTIVITY")
                            .font(TerminalFonts.header3)
                            .foregroundColor(TerminalColors.primary)
                    }
                }
                
                if viewModel.hasUnreadNotifications {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            Task {
                                await viewModel.markAllAsRead()
                            }
                        }) {
                            Text("MARK ALL")
                                .font(TerminalFonts.caption2.weight(.bold))
                                .foregroundColor(TerminalColors.primary)
                        }
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            Task {
                await viewModel.fetchNotifications()
            }
        }
    }
    
    private var statusBar: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(viewModel.hasUnreadNotifications ? TerminalColors.primary : TerminalColors.textSecondary)
                    .frame(width: 8, height: 8)
                
                if viewModel.unreadCount > 0 {
                    Text("\(viewModel.unreadCount) UNREAD")
                        .font(TerminalFonts.caption2)
                        .foregroundColor(TerminalColors.primary)
                } else {
                    Text("ALL READ")
                        .font(TerminalFonts.caption2)
                        .foregroundColor(TerminalColors.textSecondary)
                }
            }
            
            Spacer()
            
            Text("\(viewModel.notifications.count) TOTAL")
                .font(TerminalFonts.caption2)
                .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
    }
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ActivityViewModel.NotificationFilter.allCases, id: \.self) { filter in
                    Button(action: {
                        viewModel.setFilter(filter)
                    }) {
                        Text(filter.displayName)
                            .font(TerminalFonts.caption2.weight(.bold))
                            .foregroundColor(viewModel.selectedFilter == filter ? .black : TerminalColors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(viewModel.selectedFilter == filter ? TerminalColors.primary : TerminalColors.backgroundTertiary)
                            .border(viewModel.selectedFilter == filter ? TerminalColors.primary : TerminalColors.border, width: 1)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(TerminalColors.backgroundSecondary)
        .border(TerminalColors.border, width: 1)
    }
    
    private var notificationsList: some View {
        Group {
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                loadingView
            } else if viewModel.filteredNotifications.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(viewModel.filteredNotifications) { notification in
                        NotificationRow(
                            notification: notification,
                            onTap: {
                                Task {
                                    await viewModel.markAsRead(notificationId: notification.id)
                                }
                            }
                        )
                        .listRowBackground(
                            notification.isRead
                                ? TerminalColors.backgroundSecondary
                                : TerminalColors.primary.opacity(0.05)
                        )
                        .listRowSeparator(.hidden)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let notification = viewModel.filteredNotifications[index]
                            viewModel.deleteNotification(notificationId: notification.id)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .background(TerminalColors.background)
                .refreshable {
                    await viewModel.fetchNotifications()
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: TerminalColors.primary))
                .scaleEffect(1.5)
            
            Text("LOADING ACTIVITY...")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(.vertical, 64)
        .frame(maxWidth: .infinity)
    }
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 48))
                .foregroundColor(TerminalColors.textTertiary)
            
            Text("NO ACTIVITY")
                .font(TerminalFonts.caption)
                .foregroundColor(TerminalColors.textSecondary)
        }
        .padding(.vertical, 64)
        .frame(maxWidth: .infinity)
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Rectangle()
                        .fill(TerminalColors.backgroundTertiary)
                        .frame(width: 44, height: 44)
                        .border(Color(hex: notification.type.color), width: 1)
                    
                    Image(systemName: notification.type.icon)
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: notification.type.color))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.type.displayName)
                            .font(TerminalFonts.caption.weight(.bold))
                            .foregroundColor(Color(hex: notification.type.color))
                        
                        Spacer()
                        
                        Text(notification.timeAgo)
                            .font(TerminalFonts.caption2)
                            .foregroundColor(TerminalColors.textSecondary)
                    }
                    
                    Text(notification.title)
                        .font(TerminalFonts.body.weight(.medium))
                        .foregroundColor(TerminalColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(notification.message)
                        .font(TerminalFonts.caption)
                        .foregroundColor(TerminalColors.textSecondary)
                        .lineLimit(2)
                }
                
                if !notification.isRead {
                    Circle()
                        .fill(TerminalColors.primary)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
