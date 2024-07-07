//
//  TimeZonePreference.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import Foundation

enum TimeZonePreference: Codable {
    /// Always use the system time zone.
    case system

    /// Use the time zone on the calendar event if it exists.
    /// Fallback to the system time zone if it does not exist.
    case event
}
