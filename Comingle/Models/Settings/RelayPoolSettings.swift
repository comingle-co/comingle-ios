//
//  RelaySettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/11/24.
//

import SwiftData

@Model
final class RelayPoolSettings {

    var relayURLStrings: [String] = ["wss://relay.primal.net"]

    init() {
    }
}
