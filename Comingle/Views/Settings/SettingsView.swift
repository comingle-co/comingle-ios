//
//  SettingsView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import SwiftData
import SwiftUI
import NostrSDK
import Combine

struct SettingsView: View {

    @EnvironmentObject var appState: AppState

    @State private var profilePickerExpanded: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    content: {
                        DisclosureGroup(
                            isExpanded: $profilePickerExpanded,
                            content: {
                                if let appSettings = appState.appSettings {
                                    ForEach(appSettings.profiles, id: \.self) { profile in
                                        HStack {
                                            if profile == appSettings.activeProfile {
                                                ProfilePictureView(publicKeyHex: profile.publicKeyHex)
                                                    .overlay(
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(.green)
                                                            .frame(width: 16, height: 16)
                                                            .offset(x: 4, y: 4),
                                                        alignment: .bottomTrailing
                                                    )
                                            } else {
                                                ProfilePictureView(publicKeyHex: profile.publicKeyHex)
                                            }
                                            ProfileNameView(publicKeyHex: profile.publicKeyHex)
                                        }
                                        .tag(profile.publicKeyHex)
                                        .onTapGesture {
                                            appSettings.activeProfile = profile
                                            profilePickerExpanded = false
                                        }
                                        .swipeActions {
                                            if profile.publicKeyHex != nil {
                                                Button(role: .destructive) {
                                                } label: {
                                                    Label(.localizable.removeProfile, systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                    NavigationLink(destination: LoginView()) {
                                        Image(systemName: "plus.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 40)
                                        Text(.localizable.addProfile)
                                    }
                                }
                            },
                            label: {
                                ProfilePictureAndNameView(publicKeyHex: appState.appSettings?.activeProfile?.publicKeyHex)
                            }
                        )
                    },
                    header: {
                        Text(.localizable.profiles)
                    }
                )

                Section(
                    content: {
                        Label(.localizable.settingsKeys, systemImage: "key")
                        Label(.localizable.settingsRelays, systemImage: "server.rack")
                        Label(.localizable.settingsAppearance, systemImage: "eye")
                    },
                    header: {
                        Text(.localizable.settingsForProfile(activeProfileName))
                    }
                )
            }
        }
        .navigationTitle(.localizable.settings)
    }

    var activeProfileName: String {
        Utilities.shared.profileName(
            publicKeyHex: appState.appSettings?.activeProfile?.publicKeyHex,
            appState: appState
        )
    }
}

struct SettingsView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        SettingsView()
            .environmentObject(appState)
    }
}
