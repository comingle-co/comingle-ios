//
//  Utilities.swift
//  Comingle
//
//  Created by Terry Yiu on 7/9/24.
//

import NostrSDK

class Utilities {
    static let shared = Utilities()

    func profileName(publicKeyHex: String?, appState: AppState) -> String {
        if let publicKeyHex {
            if let resolvedName = appState.metadataEvents[publicKeyHex]?.resolvedName {
                return resolvedName
            } else if let publicKey = PublicKey(hex: publicKeyHex) {
                return publicKey.npub
            } else {
                return publicKeyHex
            }
        } else {
            return String(localized: .localizable.guest)
        }
    }
}
