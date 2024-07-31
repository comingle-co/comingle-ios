//
//  RSVPSortComparator.swift
//  Comingle
//
//  Created by Terry Yiu on 7/30/24.
//

import Foundation
import NostrSDK

struct RSVPSortComparator: SortComparator {
    var order: SortOrder
    let appState: AppState

    init(order: SortOrder, appState: AppState) {
        self.order = order
        self.appState = appState
    }

    func compare(_ lhs: CalendarEventRSVP, _ rhs: CalendarEventRSVP) -> ComparisonResult {
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

    private func compareForward(_ lhs: CalendarEventRSVP, _ rhs: CalendarEventRSVP) -> ComparisonResult {
        if lhs == rhs {
            return .orderedSame
        }

        switch (appState.followedPubkeys.contains(lhs.pubkey), appState.followedPubkeys.contains(rhs.pubkey)) {
        case (true, false):
            return .orderedAscending
        case (false, true):
            return .orderedDescending
        default:
            break
        }

        let lhsMetadataEvent = appState.metadataEvents[lhs.pubkey]
        let rhsMetadataEvent = appState.metadataEvents[rhs.pubkey]

        switch (lhsMetadataEvent, rhsMetadataEvent) {
        case (nil, nil):
            break
        case (nil, _):
            return .orderedDescending
        case (_, nil):
            return .orderedAscending
        default:
            break
        }

        switch (lhs.status, rhs.status) {
        case (nil, nil), (.accepted, .accepted), (.tentative, .tentative), (.declined, .declined), (.unknown, .unknown):
            break
        case (.accepted, _):
            return .orderedAscending
        case (_, .accepted):
            return .orderedDescending
        case (.tentative, _):
            return .orderedAscending
        case (_, .tentative):
            return .orderedDescending
        case (.declined, _):
            return .orderedDescending
        case (_, .declined):
            return .orderedAscending
        case (.unknown, _):
            return .orderedAscending
        default:
            break
        }

        let publicKeySortComparator = PublicKeySortComparator(order: .forward, appState: appState)
        return publicKeySortComparator.compare(lhs.pubkey, rhs.pubkey)
    }
}
