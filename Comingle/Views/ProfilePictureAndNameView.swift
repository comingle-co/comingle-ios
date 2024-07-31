//
//  ProfilePictureAndNameView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/8/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct ProfilePictureAndNameView: View {

    var publicKeyHex: String?

    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            ProfilePictureView(publicKeyHex: publicKeyHex)

            VStack(alignment: .leading) {
                Text(Utilities.shared.profileName(publicKeyHex: publicKeyHex, appState: appState))
                    .font(.subheadline)

                if let publicKeyHex, appState.followedPubkeys.contains(publicKeyHex) {
                    Image(systemName: "figure.stand.line.dotted.figure.stand")
                        .font(.footnote)
                }
            }
        }
    }
}

//struct ProfilePictureAndNameView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        ProfilePictureAndNameView(publicKeyHex: "fake-pubkey")
//            .environmentObject(appState)
//    }
//}
