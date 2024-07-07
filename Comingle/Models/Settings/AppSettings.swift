//
//  AppSettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/6/24.
//

import Foundation
import SwiftData

@Model
final class AppSettings {

    var activeProfile: Profile?

    var profiles: [Profile] = []

    init() {
    }
}
