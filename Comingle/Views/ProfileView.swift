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

    @State private var isDescriptionExpanded: Bool = false

    private let maxDescriptionLength = 140

    private var nostrProfileURL: URL? {
        guard let publicKey = PublicKey(hex: publicKeyHex) else {
            return nil
        }

        return Utilities.shared.externalNostrProfileURL(npub: publicKey.npub)
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

            if let metadataEvent = appState.metadataEvents[publicKeyHex], let description = metadataEvent.userMetadata?.about?.trimmedOrNilIfEmpty {
                VStack(alignment: .leading) {
                    if isDescriptionExpanded || description.count <= maxDescriptionLength {
                        Text(.init(description))
                            .font(.subheadline)
                    } else {
                        Text(.init(description.prefix(maxDescriptionLength) + "..."))
                            .font(.subheadline)
                    }

                    if description.count > maxDescriptionLength {
                        Button(action: {
                            isDescriptionExpanded.toggle()
                        }, label: {
                            if isDescriptionExpanded {
                                Text(.localizable.showLess)
                                    .font(.subheadline)
                            } else {
                                Text(.localizable.showMore)
                                    .font(.subheadline)
                            }
                        })
                    }
                }
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
