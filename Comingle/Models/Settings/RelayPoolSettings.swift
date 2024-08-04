//
//  RelaySettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/11/24.
//

import SwiftData

@Model
final class RelayPoolSettings {

    @Attribute(.unique) var publicKeyHex: String?

    var relaySettingsList: [RelaySettings]

    init(publicKeyHex: String?) {
        self.relaySettingsList = []
    }
}
