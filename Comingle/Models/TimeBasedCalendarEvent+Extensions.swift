//
//  TimeBasedCalendarEvent+Extensions.swift
//  Comingle
//
//  Created by Terry Yiu on 7/30/24.
//

import Foundation
import NostrSDK

extension TimeBasedCalendarEvent {
    var isUpcoming: Bool {
        guard let startTimestamp else {
            return false
        }

        guard let endTimestamp else {
            return startTimestamp >= Date.now
        }

        return startTimestamp >= Date.now || endTimestamp >= Date.now
    }

    var isPast: Bool {
        guard let startTimestamp else {
            return false
        }

        guard let endTimestamp else {
            return startTimestamp < Date.now
        }

        return endTimestamp < Date.now
    }
}
