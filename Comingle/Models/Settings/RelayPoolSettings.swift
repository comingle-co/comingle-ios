//
//  RelaySettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/11/24.
//

import SwiftData

@Model
final class RelayPoolSettings {

    var relaySettingsList: [RelaySettings]

    init() {
        self.relaySettingsList = []
    }
}
