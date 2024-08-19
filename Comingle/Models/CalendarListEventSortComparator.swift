//
//  CalendarListEventSortComparator.swift
//  Comingle
//
//  Created by Terry Yiu on 8/18/24.
//

import Foundation
import NostrSDK

struct CalendarListEventSortComparator: SortComparator {
    var order: SortOrder
    let appState: AppState

    init(order: SortOrder, appState: AppState) {
        self.order = order
        self.appState = appState
    }

    func compare(_ lhs: CalendarListEvent, _ rhs: CalendarListEvent) -> ComparisonResult {
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

    private func compareForward(_ lhs: CalendarListEvent, _ rhs: CalendarListEvent) -> ComparisonResult {
        if lhs == rhs {
            return .orderedSame
        }

        let publicKeySortComparator = PublicKeySortComparator(order: .forward, appState: appState)
        let publicKeyComparison = publicKeySortComparator.compare(lhs.pubkey, rhs.pubkey)
        if publicKeyComparison != .orderedSame {
            return publicKeyComparison
        }

        if lhs.identifier == rhs.identifier {
            // Return the newer one first if it's the same replaceable event.
            return rhs.createdDate.compare(lhs.createdDate)
        }


        let lhsTitle = lhs.title?.trimmedOrNilIfEmpty
        let rhsTitle = rhs.title?.trimmedOrNilIfEmpty

        switch (lhsTitle, rhsTitle) {
        case (nil, nil):
            return lhs.id.compare(rhs.id)
        case (_, nil):
            return .orderedAscending
        case (nil, _):
            return .orderedDescending
        default:
            return lhsTitle!.compare(rhsTitle!)
        }
    }
}
