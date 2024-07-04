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
            if order == .forward {
                return .orderedDescending
            } else {
                return .orderedAscending
            }
        }

        guard let rhsStartTimestamp = rhs.startTimestamp else {
            if order == .forward {
                return .orderedAscending
            } else {
                return .orderedDescending
            }
        }

        let lhsEndTimestamp = lhs.endTimestamp ?? lhsStartTimestamp
        let rhsEndTimestamp = rhs.endTimestamp ?? rhsStartTimestamp

        if lhsStartTimestamp < rhsStartTimestamp {
            if order == .forward {
                return .orderedAscending
            } else {
                return .orderedDescending
            }
        } else if lhsStartTimestamp > rhsStartTimestamp {
            if order == .forward {
                return .orderedDescending
            } else {
                return .orderedAscending
            }
        } else {
            if lhsEndTimestamp < rhsEndTimestamp {
                if order == .forward {
                    return .orderedAscending
                } else {
                    return .orderedDescending
                }
            } else if lhsEndTimestamp > rhsEndTimestamp {
                if order == .forward {
                    return .orderedDescending
                } else {
                    return .orderedAscending
                }
            } else {
                return .orderedSame
            }
        }
    }
}
