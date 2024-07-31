//
//  CalendarEventParticipantSortComparator.swift
//  Comingle
//
//  Created by Terry Yiu on 7/30/24.
//

import Foundation
import NostrSDK

struct CalendarEventParticipantSortComparator: SortComparator {
    var order: SortOrder
    let appState: AppState

    init(order: SortOrder, appState: AppState) {
        self.order = order
        self.appState = appState
    }

    func compare(_ lhs: CalendarEventParticipant, _ rhs: CalendarEventParticipant) -> ComparisonResult {
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

    private func compareForward(_ lhs: CalendarEventParticipant, _ rhs: CalendarEventParticipant) -> ComparisonResult {
        switch (lhs.role, rhs.role) {
        case (nil, nil):
            break
        case (nil, _):
            return .orderedDescending
        case (_, nil):
            return .orderedAscending
        default:
            break
        }

        if let lhsRole = lhs.role, let rhsRole = rhs.role {
            return lhsRole.caseInsensitiveCompare(rhsRole)
        }

        guard let lhsPubkey = lhs.pubkey, let rhsPubkey = rhs.pubkey else {
            return .orderedSame
        }

        let publicKeySortComparator = PublicKeySortComparator(order: .forward, appState: appState)
        return publicKeySortComparator.compare(lhsPubkey.hex, rhsPubkey.hex)
    }
}
