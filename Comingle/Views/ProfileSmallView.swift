//
//  ProfileSmallView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/8/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct ProfileSmallView: View {

    var publicKeyHex: String?

    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            if let publicKeyHex {
                let metadataEvent = appState.metadataEvents[publicKeyHex]

                ProfilePictureView(publicKeyHex: publicKeyHex)

                if let resolvedName = metadataEvent?.resolvedName {
                    Text(resolvedName)
                        .font(.subheadline)
                } else if let publicKey = PublicKey(hex: publicKeyHex) {
                    Text(publicKey.npub)
                        .font(.subheadline)
                } else {
                    Text(publicKeyHex)
                        .font(.subheadline)
                }
            } else {
                GuestProfilePictureView()

                Text(.localizable.guest)
                    .font(.subheadline)
            }
        }
    }
}

struct ProfileSmallView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        ProfileSmallView(publicKeyHex: "fake-pubkey")
            .environmentObject(appState)
    }
}
