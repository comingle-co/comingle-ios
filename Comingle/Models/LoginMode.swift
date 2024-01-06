//
//  LoginMode.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Foundation
import NostrSDK

enum LoginMode: CaseIterable, Identifiable {
    case none
    case guest
    case attendee
    case organizer

    var id: Self { self }

    var description: LocalizedStringResource {
        switch self {
        case .none:
            return .localizable.loginModeNone
        case .guest:
            return .localizable.loginModeGuest
        case .attendee:
            return .localizable.loginModeAttendee
        case .organizer:
            return .localizable.loginModeOrganizer
        }
    }
}
