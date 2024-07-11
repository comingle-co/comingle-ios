//
//  ProfileSettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import SwiftData

@Model
final class ProfileSettings {

    var relaySettings: RelaySettings?
    var appearanceSettings: AppearanceSettings?

    init() {
        relaySettings = RelaySettings()
        appearanceSettings = AppearanceSettings()
    }
}
