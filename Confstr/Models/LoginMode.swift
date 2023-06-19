//
//  LoginMode.swift
//  Confstr
//
//  Created by Terry Yiu on 6/18/23.
//

import Foundation
import NostrSDK

enum LoginMode {
    case none
    case guest(relayAddress: String)
    case attendee(relayAddress: String, keypair: Keypair)
    case organizer(relayAddress: String, keypair: Keypair)
}
