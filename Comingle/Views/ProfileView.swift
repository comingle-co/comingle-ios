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

    private var nostrProfileURL: URL? {
        guard let publicKey = PublicKey(hex: publicKeyHex) else {
            return nil
        }

        if let nostrURL = URL(string: "nostr:\(publicKey.npub)"), UIApplication.shared.canOpenURL(nostrURL) {
            return nostrURL
        }
        if let njumpURL = URL(string: "https://njump.me/\(publicKey.npub)"), UIApplication.shared.canOpenURL(njumpURL) {
            return njumpURL
        }
        return nil
    }

    var body: some View {
        VStack {
            ProfilePictureAndNameView(publicKeyHex: publicKeyHex)
            if let publicKey = PublicKey(hex: publicKeyHex) {
                Text(publicKey.npub)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .padding()
            }
            EventListView(eventListType: .profile(publicKeyHex))
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem {
                Menu {
                    if let publicKey = PublicKey(hex: publicKeyHex) {
                        Button(action: {
                            UIPasteboard.general.string = publicKey.npub
                        }, label: {
                            Label(.localizable.copyPublicKey, systemImage: "key")
                        })

                        if let nostrProfileURL {
                            Button(action: {
                                UIApplication.shared.open(nostrProfileURL)
                            }, label: {
                                Label(.localizable.openProfileInDefaultApp, systemImage: "link")
                            })
                        }
                    }
                } label: {
                    Label(.localizable.menu, systemImage: "ellipsis.circle")
                }
            }
        }
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
