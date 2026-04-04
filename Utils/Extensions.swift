//
//  Extensions.swift
//  TYLER'S TERMINAL
//

import SwiftUI

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
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
