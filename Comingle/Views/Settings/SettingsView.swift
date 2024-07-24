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

    @State private var viewModel: ViewModel

    @State private var profilePickerExpanded: Bool = false

    @State private var profileToSignOut: Profile?
    @State private var isShowingSignOutConfirmation: Bool = false

    init(modelContext: ModelContext, appState: AppState) {
        let viewModel = ViewModel(modelContext: modelContext, appState: appState)
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    content: {
                        DisclosureGroup(
                            isExpanded: $profilePickerExpanded,
                            content: {
                                ForEach(viewModel.profiles, id: \.self) { profile in
                                    HStack {
                                        if viewModel.isSignedInWithPrivateKey(profile) {
                                            ProfilePictureView(publicKeyHex: profile.publicKeyHex)
                                        } else {
                                            ProfilePictureView(publicKeyHex: profile.publicKeyHex)
                                                .overlay(
                                                    Image(systemName: "lock.fill")
                                                        .foregroundColor(.secondary)
                                                        .frame(width: 16, height: 16)
                                                        .offset(x: 4, y: 4),
                                                    alignment: .bottomTrailing
                                                )
                                        }
                                        if viewModel.isActiveProfile(profile) {
                                            ProfileNameView(publicKeyHex: profile.publicKeyHex)
                                                .foregroundStyle(.accent)
                                        } else {
                                            ProfileNameView(publicKeyHex: profile.publicKeyHex)
                                        }
                                    }
                                    .tag(profile.publicKeyHex)
                                    .onTapGesture {
                                        viewModel.updateActiveProfile(profile)
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
                                NavigationLink(destination: LoginView(modelContext: viewModel.modelContext, appState: viewModel.appState)) {
                                    Image(systemName: "plus.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40)
                                    Text(.localizable.addProfile)
                                }
                            },
                            label: {
                                let publicKeyHex = viewModel.publicKeyHex
                                if let publicKeyHex, PublicKey(hex: publicKeyHex) != nil {
                                    if viewModel.isActiveProfileSignedInWithPrivateKey {
                                        ProfilePictureView(publicKeyHex: publicKeyHex)
                                    } else {
                                        ProfilePictureView(publicKeyHex: publicKeyHex)
                                            .overlay(
                                                Image(systemName: "lock.fill")
                                                    .foregroundColor(.secondary)
                                                    .frame(width: 16, height: 16)
                                                    .offset(x: 4, y: 4),
                                                alignment: .bottomTrailing
                                            )
                                    }
                                } else {
                                    GuestProfilePictureView()
                                        .overlay(
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(.secondary)
                                                .frame(width: 16, height: 16)
                                                .offset(x: 4, y: 4),
                                            alignment: .bottomTrailing
                                        )
                                }
                                ProfileNameView(publicKeyHex: publicKeyHex)
                            }
                        )

                        if let publicKeyHex = viewModel.publicKeyHex, PublicKey(hex: publicKeyHex) != nil {
                            NavigationLink(destination: ProfileView(publicKeyHex: publicKeyHex)) {
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
                        let publicKeyHex = viewModel.publicKeyHex
                        if let publicKeyHex, let publicKey = PublicKey(hex: publicKeyHex) {
                            NavigationLink(destination: KeysSettingsView(publicKey: publicKey)) {
                                Label(.localizable.settingsKeys, systemImage: "key")
                            }
                        }
                        NavigationLink(destination: RelaysSettingsView(modelContext: viewModel.modelContext, publicKeyHex: viewModel.publicKeyHex)) {
                            Label(.localizable.settingsRelays, systemImage: "server.rack")
                        }
                        NavigationLink(destination: AppearanceSettingsView(modelContext: viewModel.modelContext, publicKeyHex: viewModel.publicKeyHex)) {
                            Label(.localizable.settingsAppearance, systemImage: "eye")
                        }
                    },
                    header: {
                        Text(.localizable.settingsForProfile(viewModel.activeProfileName))
                    }
                )

                if let activeProfile = viewModel.activeProfile, activeProfile.publicKeyHex != nil {
                    Section {
                        Button(
                            action: {
                                profileToSignOut = activeProfile
                                isShowingSignOutConfirmation = true
                            },
                            label: {
                                Label(.localizable.signOutProfile(
                                    viewModel.activeProfileName
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
            if let profileToSignOut, let publicKeyHex = profileToSignOut.publicKeyHex {
                Button(role: .destructive) {
                    viewModel.signOut(profileToSignOut)
                    self.profileToSignOut = nil
                } label: {
                    Text(.localizable.signOutProfile(
                        viewModel.profileName(publicKeyHex: profileToSignOut.publicKeyHex)
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
}

extension SettingsView {
    class ViewModel: ObservableObject {
        let modelContext: ModelContext
        let appState: AppState
        var profilePickerExpanded: Bool = false

        init(modelContext: ModelContext, appState: AppState) {
            self.modelContext = modelContext
            self.appState = appState
        }

        var publicKeyHex: String? {
            appState.appSettings?.activeProfile?.publicKeyHex
        }

        var activeProfile: Profile? {
            appState.appSettings?.activeProfile
        }

        var activeProfileName: String {
            profileName(publicKeyHex: publicKeyHex)
        }

        var profiles: [Profile] {
            appState.profiles
        }

        func profileName(publicKeyHex: String?) -> String {
            Utilities.shared.profileName(
                publicKeyHex: publicKeyHex,
                appState: appState
            )
        }

        var isActiveProfileSignedInWithPrivateKey: Bool {
            guard let activeProfile = appState.appSettings?.activeProfile else {
                return false
            }
            return isSignedInWithPrivateKey(activeProfile)
        }

        func isSignedInWithPrivateKey(_ profile: Profile) -> Bool {
            guard let publicKeyHex = profile.publicKeyHex, let publicKey = PublicKey(hex: publicKeyHex) else {
                return false
            }
            return PrivateKeySecureStorage.shared.keypair(for: publicKey) != nil
        }

        func signOut(_ profile: Profile) {
            if let publicKeyHex = profile.publicKeyHex, let publicKey = PublicKey(hex: publicKeyHex) {
                appState.privateKeySecureStorage.delete(for: publicKey)
            }
            if let appSettings = appState.appSettings, appSettings.activeProfile == profile {
                appSettings.activeProfile = appState.profiles.first(where: { $0 != profile })
            }
            appState.profiles.removeAll(where: { $0 == profile })
            modelContext.delete(profile)
        }

        func isActiveProfile(_ profile: Profile) -> Bool {
            guard let appSettings = appState.appSettings else {
                return false
            }
            return appSettings.activeProfile == profile
        }

        func updateActiveProfile(_ profile: Profile) {
            guard let appSettings = appState.appSettings else {
                return
            }

            appSettings.activeProfile = profile

            if profile.publicKeyHex == nil {
                appState.activeTab = .explore
            }

            appState.updateRelayPool()
            appState.refresh()
        }
    }
}

//struct SettingsView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        SettingsView()
//            .environmentObject(appState)
//    }
//}
