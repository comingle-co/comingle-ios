//
//  AppearanceSettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import SwiftData

@Model
final class AppearanceSettings {

    var timeZonePreference: TimeZonePreference = TimeZonePreference.event

    init() {
    }
}
