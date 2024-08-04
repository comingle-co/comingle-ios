//
//  RelaySubscriptionMetadata.swift
//  Comingle
//
//  Created by Terry Yiu on 8/3/24.
//

import Foundation
import SwiftData

@Model
final class RelaySubscriptionMetadata {

    @Attribute(.unique) var publicKeyHex: String?

    var lastBootstrapped: Date?
    var lastPulledAllTimeBasedCalendarEvents: Date?
    var lastPulledEventsFromFollows: Date?

    init(publicKeyHex: String? = nil) {
        self.publicKeyHex = publicKeyHex
    }
}
