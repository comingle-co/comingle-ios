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
    let appState: AppState

    init(order: SortOrder, appState: AppState) {
        self.order = order
        self.appState = appState
    }

    func compare(_ lhs: EventCreationParticipant, _ rhs: EventCreationParticipant) -> ComparisonResult {
        let publicKeySortComparator = PublicKeySortComparator(order: order, appState: appState)
        return publicKeySortComparator.compare(lhs.publicKeyHex, rhs.publicKeyHex)
    }
}
