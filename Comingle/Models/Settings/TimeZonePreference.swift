//
//  TimeZonePreference.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import Foundation

enum TimeZonePreference: CaseIterable, Codable {
    /// Use the time zone on the calendar event if it exists.
    /// Fallback to the system time zone if it does not exist.
    case event

    /// Always use the system time zone.
    case system

    var localizedString: String {
        switch self {
        case .event:
            String(localized: "Event", comment: "Picker option settings for using the event time zone if it exists.")
        case .system:
            String(localized: "System", comment: "Picker option settings for using the system time zone.")
        }
    }
}
