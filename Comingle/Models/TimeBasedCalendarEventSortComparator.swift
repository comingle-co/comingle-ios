//
//  TimeBasedCalendarEventSortComparator.swift
//  Comingle
//
//  Created by Terry Yiu on 7/4/24.
//

import Foundation
import NostrSDK

struct TimeBasedCalendarEventSortComparator: SortComparator {
    var order: SortOrder

    func compare(_ lhs: TimeBasedCalendarEvent, _ rhs: TimeBasedCalendarEvent) -> ComparisonResult {
        if lhs == rhs {
            return .orderedSame
        }

        guard let lhsStartTimestamp = lhs.startTimestamp else {
            return .orderedDescending
        }

        guard let rhsStartTimestamp = rhs.startTimestamp else {
            return .orderedAscending
        }

        let lhsEndTimestamp = lhs.endTimestamp ?? lhsStartTimestamp
        let rhsEndTimestamp = rhs.endTimestamp ?? rhsStartTimestamp

        if lhsStartTimestamp < rhsStartTimestamp {
            return .orderedAscending
        } else if lhsStartTimestamp > rhsStartTimestamp {
            return .orderedDescending
        } else {
            if lhsEndTimestamp < rhsEndTimestamp {
                return .orderedAscending
            } else if lhsEndTimestamp > rhsEndTimestamp {
                return .orderedDescending
            } else {
                return .orderedSame
            }
        }
    }
}
