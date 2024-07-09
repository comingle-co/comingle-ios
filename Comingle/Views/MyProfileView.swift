//
//  MyProfileView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/7/24.
//

import Kingfisher
import NostrSDK
import SwiftUI

struct MyProfileView: View {

    @EnvironmentObject var appState: AppState

    @State private var showProfileSwitcher: Bool = false

    var body: some View {
        List {
            Section(
                isExpanded: $showProfileSwitcher,
                content: {
                    if let appSettings = appState.appSettings {
                        let profiles = appSettings.profiles.filter { $0 != appState.appSettings?.activeProfile }
                        VStack(alignment: .leading) {
                            ForEach(profiles, id: \.self) { profile in
                                HStack {
                                    if let publicKeyHex = profile.publicKeyHex {
                                        ProfileSmallView(publicKeyHex: publicKeyHex, appState: appState)
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40)
                                            .clipShape(.circle)

                                        Text(.localizable.guest)
                                            .font(.subheadline)
                                    }
                                }
                                .onTapGesture {
                                    appSettings.activeProfile = profile
                                    showProfileSwitcher = false
                                }
                            }
                        }
                    }
                },
                header: {
                    HStack {
                        if let publicKeyHex = appState.appSettings?.activeProfile?.publicKeyHex {
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
                        } else {
                            Image(systemName: "person.crop.circle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40)
                                .clipShape(.circle)

                            Text(.localizable.guest)
                                .font(.subheadline)
                        }
                    }
                    .onTapGesture {
                        showProfileSwitcher.toggle()
                    }
                }
            )
        }
    }
}

struct MyProfileView_Previews: PreviewProvider {

    static var previews: some View {
        MyProfileView()
    }
}
