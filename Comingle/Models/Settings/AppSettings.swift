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

    var profiles: [Profile]

    init(activeProfile: Profile = Profile(), profiles: [Profile] = []) {
        self.activeProfile = activeProfile

        if profiles.contains(activeProfile) {
            self.profiles = profiles
        } else {
            self.profiles = profiles + [activeProfile]
        }
    }
}
