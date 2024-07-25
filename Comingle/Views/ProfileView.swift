//
//  ProfileView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/7/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct ProfileView: View {

    @EnvironmentObject var appState: AppState

    @State var publicKeyHex: String

    var body: some View {
        VStack {
            ProfilePictureAndNameView(publicKeyHex: publicKeyHex)
            if let publicKey = PublicKey(hex: publicKeyHex) {
                Text(publicKey.npub)
            }
            EventListView(eventListType: .profile(publicKeyHex))
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

//struct ProfileView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        ProfileView(publicKeyHex: "fake-pubkey")
//            .environmentObject(appState)
//    }
//}
