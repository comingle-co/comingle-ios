//
//  PersistentNostrEvent.swift
//  Comingle
//
//  Created by Terry Yiu on 7/23/24.
//

import Foundation
import NostrSDK
import SwiftData

@Model
class PersistentNostrEvent {
    @Attribute(.unique) var eventId: String

    @Attribute(.transformable(by: NostrEventValueTransformer.self)) var nostrEvent: NostrEvent

    var relays: [URL] = []

    init(nostrEvent: NostrEvent, relays: [URL] = []) {
        self.eventId = nostrEvent.id
        self.nostrEvent = nostrEvent
        self.relays = relays
    }
}
