//
//  MetadataEvent+Extensions.swift
//  Comingle
//
//  Created by Terry Yiu on 6/29/24.
//

import NostrSDK

extension MetadataEvent {
    var resolvedName: String {
        guard let userMetadata, let bestName = userMetadata.displayName ?? userMetadata.name else {
            return PublicKey(hex: pubkey)?.npub ?? pubkey
        }

        let trimmedName = bestName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            return PublicKey(hex: pubkey)?.npub ?? pubkey
        }

        return trimmedName
    }
}
