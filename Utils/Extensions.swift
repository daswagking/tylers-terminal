//
//  Extensions.swift
//  TYLER'S TERMINAL
//

import SwiftUI
import Combine

extension String {
    var isValidUsername: Bool {
        let regex = "^[a-zA-Z0-9_]{3,20}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: self)
    }
    
    var isValidPassword: Bool {
        return count >= 6
    }
    
    func truncated(to length: Int, trailing: String = "...") -> String {
        if count > length {
            return String(prefix(length)) + trailing
        }
        return self
    }
}

extension Date {
    var timeAgoDisplay: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: self, to: now)
        
        if let week = components.weekOfYear, week > 0 {
            return week == 1 ? "1W AGO" : "\(week)W AGO"
        } else if let day = components.day, day > 0 {
            return day == 1 ? "1D AGO" : "\(day)D AGO"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1H AGO" : "\(hour)H AGO"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1M AGO" : "\(minute)M AGO"
        } else {
            return "JUST NOW"
        }
    }
    
    var terminalFormat: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: self)
    }
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension Publisher {
    func debounceSink(
        for dueTime: DispatchQueue.SchedulerTimeType.Stride,
        scheduler: DispatchQueue = .main,
        receiveValue: @escaping (Output) -> Void
    ) -> AnyCancellable {
        debounce(for: dueTime, scheduler: scheduler)
            .sink(receiveCompletion: { _ in }, receiveValue: receiveValue)
    }
}

extension UserDefaults {
    func set<T: Encodable>(_ object: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(object) {
            set(data, forKey: key)
        }
    }
    
    func get<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

extension Notification.Name {
    static let newTradePosted = Notification.Name("NewTradePosted")
    static let userDidSignIn = Notification.Name("UserDidSignIn")
    static let userDidSignOut = Notification.Name("UserDidSignOut")
}

enum LoadingState: Equatable {
    case idle
    case loading
    case success
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}
