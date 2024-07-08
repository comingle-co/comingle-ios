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

    var publicKeyHex: String
    @State var appState: AppState

    var body: some View {
        HStack {
            let metadataEvent = appState.metadataEvents[publicKeyHex]

            if let pictureURL = metadataEvent?.userMetadata?.pictureURL {
                KFImage.url(pictureURL)
                    .resizable()
                    .placeholder { ProgressView() }
                    .scaledToFit()
                    .frame(width: 40)
                    .clipShape(.circle)
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40)
                    .clipShape(.circle)
            }

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
        }
    }
}

struct ProfileSmallView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        ProfileSmallView(publicKeyHex: "fake-pubkey", appState: appState)
    }
}
