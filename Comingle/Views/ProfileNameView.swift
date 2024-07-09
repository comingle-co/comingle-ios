//
//  ProfileNameView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/9/24.
//

import NostrSDK
import SwiftUI

struct ProfileNameView: View {
    var publicKeyHex: String?

    @EnvironmentObject var appState: AppState

    var body: some View {
        if let publicKeyHex {
            let metadataEvent = appState.metadataEvents[publicKeyHex]

            if let resolvedName = metadataEvent?.resolvedName {
                Text(resolvedName)
            } else if let publicKey = PublicKey(hex: publicKeyHex) {
                Text(publicKey.npub)
            } else {
                Text(publicKeyHex)
            }
        } else {
            Text(.localizable.guest)
        }
    }
}

#Preview {
    ProfileNameView()
}
