//
//  AppearanceSettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import SwiftData

@Model
final class AppearanceSettings {

    @Attribute(.unique) var publicKeyHex: String?

    var timeZonePreference: TimeZonePreference = TimeZonePreference.event

    init(publicKeyHex: String?) {
        self.publicKeyHex = publicKeyHex
    }
}
