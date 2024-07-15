//
//  SettingsView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import NostrSDK
import SwiftData
import SwiftUI

struct SettingsView: View {

    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var appState: AppState

    @State private var profilePickerExpanded: Bool = false

    @State private var profileToSignOut: Profile?
    @State private var isShowingSignOutConfirmation: Bool = false

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
                                                    profileToSignOut = profile
                                                    isShowingSignOutConfirmation = true
                                                } label: {
                                                    Label(.localizable.signOut, systemImage: "door.left.hand.open")
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

                        if let publicKey = appState.publicKey {
                            NavigationLink(destination: ProfileView(publicKeyHex: publicKey.hex)) {
                                Text(.localizable.viewProfile)
                            }
                        }
                    },
                    header: {
                        Text(.localizable.profiles)
                    }
                )

                Section(
                    content: {
                        if let publicKey = appState.publicKey {
                            NavigationLink(destination: KeysSettingsView(publicKey: publicKey)) {
                                Label(.localizable.settingsKeys, systemImage: "key")
                            }
                        }
                        NavigationLink(destination: RelaysSettingsView()) {
                            Label(.localizable.settingsRelays, systemImage: "server.rack")
                        }
                        NavigationLink(destination: AppearanceSettingsView()) {
                            Label(.localizable.settingsAppearance, systemImage: "eye")
                        }
                    },
                    header: {
                        Text(.localizable.settingsForProfile(activeProfileName))
                    }
                )

                if appState.publicKey != nil, let activeProfile = appState.appSettings?.activeProfile {
                    Section {
                        Button(
                            action: {
                                profileToSignOut = activeProfile
                                isShowingSignOutConfirmation = true
                            },
                            label: {
                                Label(.localizable.signOutProfile(
                                    activeProfileName
                                ), systemImage: "door.left.hand.open")
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle(.localizable.settings)
        .confirmationDialog(
            Text(.localizable.signOutFromDevice),
            isPresented: $isShowingSignOutConfirmation
        ) {
            if let appSettings = appState.appSettings, let profileToSignOut, profileToSignOut.publicKeyHex != nil {
                Button(role: .destructive) {
                    if appSettings.activeProfile == profileToSignOut {
                        appSettings.activeProfile = appSettings.profiles.first(where: { $0 != profileToSignOut })
                    }
                    appSettings.profiles.removeAll(where: { $0 == profileToSignOut })
                    self.profileToSignOut = nil
                    modelContext.delete(profileToSignOut)
                } label: {
                    Text(.localizable.signOutProfile(
                        Utilities.shared.profileName(publicKeyHex: profileToSignOut.publicKeyHex, appState: appState)
                    ))
                }
            }

            Button(role: .cancel) {
                profileToSignOut = nil
            } label: {
                Text(.localizable.cancel)
            }
        } message: {
            Text(.localizable.signOutMessage)
        }
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
