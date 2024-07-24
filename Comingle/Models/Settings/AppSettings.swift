//
//  AppSettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import SwiftData

@Model
final class AppSettings {

    var activeProfile: Profile?

    init(activeProfile: Profile = Profile()) {
        self.activeProfile = activeProfile
    }
}
