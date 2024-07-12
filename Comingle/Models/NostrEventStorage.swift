//
//  NostrEventStorage.swift
//  Comingle
//
//  Created by Terry Yiu on 7/11/24.
//

import NostrSDK
import SwiftData

@Model
class NostrEventStorage {
    var events: Set<NostrEvent>

    init() {
        events = []
    }
}
