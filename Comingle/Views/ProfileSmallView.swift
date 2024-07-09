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
            ProfilePictureView(publicKeyHex: publicKeyHex)
            Text(Utilities.shared.profileName(publicKeyHex: publicKeyHex, appState: appState))
                .font(.subheadline)
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
