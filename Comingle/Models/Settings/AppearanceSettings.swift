//
//  AppearanceSettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import Foundation
import SwiftData

@Model
final class AppearanceSettings {

    var timeZonePreference: TimeZonePreference

    init() {
        timeZonePreference = .system
    }
}