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
            } else {
                return abbreviatedPublicKey(publicKeyHex)
            }
        } else {
            return String(localized: .localizable.guest)
        }
    }

    func abbreviatedPublicKey(_ publicKeyHex: String) -> String {
        if let publicKey = PublicKey(hex: publicKeyHex) {
            return "\(publicKey.npub.prefix(12)):\(publicKey.npub.suffix(12))"
        } else {
            return publicKeyHex
        }
    }
}
