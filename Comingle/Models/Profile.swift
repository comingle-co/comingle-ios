//
//  Profile.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import SwiftData

@Model
final class Profile {

    @Attribute(.unique) var publicKeyHex: String?

    @Relationship(deleteRule: .cascade) var profileSettings: ProfileSettings?

    init(publicKeyHex: String? = nil) {
        self.publicKeyHex = publicKeyHex
        self.profileSettings = ProfileSettings()
    }
}
