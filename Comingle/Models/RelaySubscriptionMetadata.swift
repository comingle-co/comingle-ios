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
    var lastBootstrapped: Date?
    var lastPulledAllTimeBasedCalendarEvents: Date?
    var lastPulledMetadataEvents: Date?

    init() {

    }
}
