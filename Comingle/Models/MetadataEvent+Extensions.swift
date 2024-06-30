//
//  MetadataEvent+Extensions.swift
//  Comingle
//
//  Created by Terry Yiu on 6/29/24.
//

import Foundation
import NostrSDK

extension MetadataEvent {
    var resolvedName: String {
        guard let userMetadata, let bestName = userMetadata.name ?? userMetadata.displayName else {
            return PublicKey(hex: pubkey)?.npub ?? pubkey
        }

        let trimmedName = bestName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return PublicKey(hex: pubkey)?.npub ?? pubkey
        }

        return trimmedName
    }
}
