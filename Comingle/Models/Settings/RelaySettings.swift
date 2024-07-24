//
//  RelaySettings.swift
//  Comingle
//
//  Created by Terry Yiu on 7/14/24.
//

import Foundation
import SwiftData

@Model
final class RelaySettings {

    var relayURLString: String
    var read: Bool
    var write: Bool

    init(relayURLString: String, read: Bool = true, write: Bool = true) {
        self.relayURLString = relayURLString
        self.read = read
        self.write = write
    }
}
