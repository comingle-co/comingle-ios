//
//  ProfileSettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import SwiftData

@Model
final class ProfileSettings {

    var relayPoolSettings: RelayPoolSettings?
    var appearanceSettings: AppearanceSettings?

    init() {
        relayPoolSettings = RelayPoolSettings()
        appearanceSettings = AppearanceSettings()
    }
}
