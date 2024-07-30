//
//  EventCreationParticipantSortComparator.swift
//  Comingle
//
//  Created by Terry Yiu on 7/30/24.
//

import Foundation
import NostrSDK

struct EventCreationParticipantSortComparator: SortComparator {
    var order: SortOrder
    var appState: AppState

    init(order: SortOrder, appState: AppState) {
        self.order = order
        self.appState = appState
    }

    func compare(_ lhs: EventCreationParticipant, _ rhs: EventCreationParticipant) -> ComparisonResult {
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

    private func compareForward(_ lhs: EventCreationParticipant, _ rhs: EventCreationParticipant) -> ComparisonResult {
        if lhs.publicKeyHex == rhs.publicKeyHex {
            return .orderedSame
        }

        let lhsMetadataEvent = appState.metadataEvents[lhs.publicKeyHex]
        let rhsMetadataEvent = appState.metadataEvents[rhs.publicKeyHex]

        switch (lhsMetadataEvent, rhsMetadataEvent) {
        case (nil, _):
            return .orderedDescending
        case (_, nil):
            return .orderedAscending
        default:
            break
        }

        guard let lhsMetadataEvent, let rhsMetadataEvent else {
            return lhs.publicKeyHex.caseInsensitiveCompare(rhs.publicKeyHex)
        }

        return lhsMetadataEvent.resolvedName.localizedCaseInsensitiveCompare(rhsMetadataEvent.resolvedName)
    }
}
