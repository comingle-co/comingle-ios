//
//  TimeZoneSortComparator.swift
//  Comingle
//
//  Created by Terry Yiu on 7/29/24.
//

import Foundation

struct TimeZoneSortComparator: SortComparator {
    var order: SortOrder
    var date: Date

    init(order: SortOrder, date: Date) {
        self.order = order
        self.date = date
    }

    func compare(_ lhs: TimeZone, _ rhs: TimeZone) -> ComparisonResult {
        let comparisonResult = compareForward(lhs, rhs)
        switch order {
        case .forward:
            return comparisonResult
        case .reverse:
            switch comparisonResult {
            case .orderedAscending:
                return .orderedDescending
            case .orderedDescending:
                return .orderedAscending
            case .orderedSame:
                return .orderedSame
            }
        }
    }

    private func compareForward(_ lhs: TimeZone, _ rhs: TimeZone) -> ComparisonResult {
        if lhs == rhs {
            return .orderedSame
        }

        let lhsSeconds = lhs.secondsFromGMT(for: date)
        let rhsSeconds = rhs.secondsFromGMT(for: date)

        if lhsSeconds == rhsSeconds {
            return lhs.identifier.compare(rhs.identifier)
        }

        if lhsSeconds < rhsSeconds {
            return .orderedAscending
        } else if lhsSeconds > rhsSeconds {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }
}
