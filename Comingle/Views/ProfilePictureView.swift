//
//  ProfilePictureView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/8/24.
//

import Kingfisher
import SwiftUI

struct ProfilePictureView: View {

    let publicKeyHex: String?
    var size: CGFloat = 40

    @EnvironmentObject var appState: AppState

    var body: some View {
        if let publicKeyHex,
           let pictureURL = appState.metadataEvents[publicKeyHex]?.userMetadata?.pictureURL ?? roboHashURL {
            KFImage.url(pictureURL)
                .resizable()
                .placeholder { ProgressView() }
                .scaledToFit()
                .frame(width: size)
                .clipShape(.circle)
        } else {
            GuestProfilePictureView(size: size)
        }
    }

    private var roboHashURL: URL? {
        guard let publicKeyHex else {
            return nil
        }

        return URL(string: "https://robohash.org/\(publicKeyHex)?set=set4")
    }
}

//struct ProfilePictureView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        ProfilePictureView(publicKeyHex: "fake-pubkey")
//    }
//}
