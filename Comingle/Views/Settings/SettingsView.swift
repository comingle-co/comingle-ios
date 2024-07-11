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

    @State private var profileToRemove: Profile?
    @State private var isShowingProfileRemovalConfirmation: Bool = false

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
                                                    profileToRemove = profile
                                                    isShowingProfileRemovalConfirmation = true
                                                } label: {
                                                    Label(.localizable.remove, systemImage: "trash")
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

                if let activeProfile = appState.appSettings?.activeProfile {
                    Section {
                        Button(
                            action: {
                                profileToRemove = activeProfile
                                isShowingProfileRemovalConfirmation = true
                            },
                            label: {
                                Label(.localizable.removeProfile(
                                    activeProfileName
                                ), systemImage: "trash")
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle(.localizable.settings)
        .confirmationDialog(
            Text(.localizable.removeProfileFromDevice),
            isPresented: $isShowingProfileRemovalConfirmation
        ) {
            if let appSettings = appState.appSettings, let profileToRemove {
                Button(role: .destructive) {
                    if appSettings.activeProfile == profileToRemove {
                        appSettings.activeProfile = appSettings.profiles.first(where: { $0 != profileToRemove })
                    }
                    appSettings.profiles.removeAll(where: { $0 == profileToRemove })
                    self.profileToRemove = nil
                    modelContext.delete(profileToRemove)
                } label: {
                    Text(.localizable.removeProfile(
                        Utilities.shared.profileName(publicKeyHex: profileToRemove.publicKeyHex, appState: appState)
                    ))
                }
            }

            Button(role: .cancel) {
                profileToRemove = nil
            } label: {
                Text(.localizable.cancel)
            }
        } message: {
            Text(.localizable.profileRemovalMessage)
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
