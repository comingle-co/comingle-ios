//
//  LoginMode.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Foundation
import NostrSDK

enum LoginMode: CustomStringConvertible, CaseIterable, Identifiable {
    case none
    case guest
    case attendee
    case organizer

    var id: Self { self }

    var description: String {
        switch self {
        case .none:
            return NSLocalizedString("None", comment: "")
        case .guest:
            return NSLocalizedString("Guest", comment: "")
        case .attendee:
            return NSLocalizedString("Attendee", comment: "")
        case .organizer:
            return NSLocalizedString("Organizer", comment: "")
        }
    }
}
