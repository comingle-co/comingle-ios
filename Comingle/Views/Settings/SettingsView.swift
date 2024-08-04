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

    init(appState: AppState) {
        let viewModel = ViewModel(appState: appState)
        _viewModel = State(initialValue: viewModel)
    }

    var profilesSection: some View {
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
                                    ImageOverlayView(imageSystemName: "lock.fill", overlayBackgroundColor: .accent) {
                                        ProfilePictureView(publicKeyHex: profile.publicKeyHex)
                                    }
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

                        Button(action: {
                            viewModel.isLoginViewPresented = true
                        }, label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40)
                                Text(.localizable.addProfile)
                            }
                        })
                    },
                    label: {
                        let publicKeyHex = viewModel.publicKeyHex
                        if let publicKeyHex, PublicKey(hex: publicKeyHex) != nil {
                            if viewModel.isActiveProfileSignedInWithPrivateKey {
                                ProfilePictureView(publicKeyHex: publicKeyHex)
                            } else {
                                ImageOverlayView(imageSystemName: "lock.fill", overlayBackgroundColor: .accent) {
                                    ProfilePictureView(publicKeyHex: publicKeyHex)
                                }
                            }
                        } else {
                            ImageOverlayView(imageSystemName: "lock.fill", overlayBackgroundColor: .accent) {
                                GuestProfilePictureView()
                            }
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
    }

    var profileSettingsSection: some View {
        Section(
            content: {
                let publicKeyHex = viewModel.publicKeyHex
                if let publicKeyHex, let publicKey = PublicKey(hex: publicKeyHex) {
                    NavigationLink(destination: KeysSettingsView(publicKey: publicKey)) {
                        Label(.localizable.settingsKeys, systemImage: "key")
                    }
                }
                NavigationLink(destination: RelaysSettingsView(modelContext: viewModel.appState.modelContext, publicKeyHex: viewModel.publicKeyHex)) {
                    Label(.localizable.settingsRelays, systemImage: "server.rack")
                }
                NavigationLink(destination: AppearanceSettingsView(modelContext: viewModel.appState.modelContext, publicKeyHex: viewModel.publicKeyHex)) {
                    Label(.localizable.settingsAppearance, systemImage: "eye")
                }
            },
            header: {
                Text(.localizable.settingsForProfile(viewModel.activeProfileName))
            }
        )
    }

    var aboutSection: some View {
        Section(
            content: {
                LabeledContent(String(localized: .localizable.version), value: viewModel.appVersion)

                NavigationLink(destination: AcknowledgementsView()) {
                    Text(.localizable.acknowledgements)
                }

                if let url = URL(string: "https://github.com/comingle-co/comingle-ios/issues") {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }, label: {
                        Text(.localizable.reportIssue)
                    })
                }
            },
            header: {
                Text(.localizable.settingsAbout)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                profilesSection

                profileSettingsSection

                aboutSection

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
        .sheet(isPresented: $viewModel.isLoginViewPresented) {
            NavigationStack {
                LoginView(appState: viewModel.appState)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
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
                        viewModel.profileName(publicKeyHex: publicKeyHex)
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
    @Observable class ViewModel {
        let appState: AppState
        var profilePickerExpanded: Bool = false
        var isLoginViewPresented: Bool = false

        init(appState: AppState) {
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
            appState.deleteProfile(profile)
        }

        func isActiveProfile(_ profile: Profile) -> Bool {
            return appState.appSettings?.activeProfile == profile
        }

        func updateActiveProfile(_ profile: Profile) {
            guard let appSettings = appState.appSettings, appSettings.activeProfile != profile else {
                return
            }

            appSettings.activeProfile = profile

            appState.followedPubkeys.removeAll()

            if profile.publicKeyHex == nil {
                appState.activeTab = .explore
            } else if appState.publicKey != nil {
                appState.refreshFollowedPubkeys()
            }

            appState.updateRelayPool()
            appState.refresh(hardRefresh: true)
        }

        var appVersion: String {
            guard let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"],
                  let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"]
            else {
                return String(localized: .localizable.appVersionUnknown)
            }

            return String(localized: .localizable.appVersion(String(describing: shortVersion), String(describing: bundleVersion)))
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
