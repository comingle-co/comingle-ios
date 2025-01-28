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
    @State private var isShowingAddProfileConfirmation: Bool = false

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
                                viewModel.appState.updateActiveProfile(profile)
                                profilePickerExpanded = false
                            }
                            .swipeActions {
                                if profile.publicKeyHex != nil {
                                    Button(role: .destructive) {
                                        profileToSignOut = profile
                                        isShowingSignOutConfirmation = true
                                    } label: {
                                        Label(String(localized: "Sign Out", comment: "Label indicating that the button signs out of a profile."), systemImage: "door.left.hand.open")
                                    }
                                }
                            }
                        }

                        Button(action: {
                            isShowingAddProfileConfirmation = true
                        }, label: {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40)
                                Text("Add Profile", comment: "Button to add a profile.")
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
                        Text("View Profile", comment: "Button to view the active profile.")
                    }
                }
            },
            header: {
                Text("Profiles", comment: "Section title for Profiles in the settings view.")
            }
        )
    }

    var profileSettingsSection: some View {
        Section(
            content: {
                let publicKeyHex = viewModel.publicKeyHex
                if let publicKeyHex, let publicKey = PublicKey(hex: publicKeyHex) {
                    NavigationLink(destination: KeysSettingsView(publicKey: publicKey)) {
                        Label(String(localized: "Keys", comment: "Settings section for Nostr key management."), systemImage: "key")
                    }
                }
                NavigationLink(destination: RelaysSettingsView()) {
                    Label(String(localized: "Relays", comment: "Settings section for relay management."), systemImage: "server.rack")
                }
                NavigationLink(destination: AppearanceSettingsView(modelContext: viewModel.appState.modelContext, publicKeyHex: viewModel.publicKeyHex)) {
                    Label(String(localized: "Appearance", comment: "Settings section for appearance of the app."), systemImage: "eye")
                }
            },
            header: {
                Text("Settings for \(viewModel.activeProfileName)", comment: "Section title for settings for profile")
            }
        )
    }

    var aboutSection: some View {
        Section(
            content: {
                LabeledContent(String(format: String(localized: "Version", comment: "Label for the app version in the settings view.")), value: viewModel.appVersion)

                NavigationLink(destination: AcknowledgementsView()) {
                    Text("Acknowledgements", comment: "View for seeing the acknowledgements of projects that this app depends on.")
                }

                if let comingleProfileURL = Utilities.shared.externalNostrProfileURL(npub: "npub1c0nfstrlj0jy8kvl953v84hudwnpgad0zx709z0ey7nmjp0llegslzg243") {
                    Button(action: {
                        UIApplication.shared.open(comingleProfileURL)
                    }, label: {
                        Text("Comingle Profile", comment: "Button to open the Nostr profile of the Comingle account.")
                    })
                }

                if let url = URL(string: "https://github.com/comingle-co/comingle-ios/issues") {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }, label: {
                        Text("Report an Issue", comment: "Button to report an issue about the app.")
                    })
                }
            },
            header: {
                Text("About", comment: "Settings about section title.")
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
                                Label(
                                    String(localized: "Sign Out of \(viewModel.activeProfileName)", comment: "Button to sign out of a profile from the device."),
                                    systemImage: "door.left.hand.open"
                                )
                            }
                        )
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Settings", comment: "Navigation title for the settings view."))
        .sheet(isPresented: $viewModel.isSignInViewPresented) {
            NavigationStack {
                SignInView()
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .confirmationDialog(
            Text("Add Profile", comment: "Button to add a profile."),
            isPresented: $isShowingAddProfileConfirmation
        ) {
            NavigationLink(destination: CreateProfileView(appState: viewModel.appState)) {
                Text("Create Profile", comment: "Button to create a profile.")
            }

            Button(action: {
                viewModel.isSignInViewPresented = true
            }, label: {
                Text("Sign Into Existing Profile", comment: "Button to sign into existing profile.")
            })
        }
        .confirmationDialog(
            Text("Sign out of profile?", comment: "Title of confirmation dialog when user initiates a profile sign out."),
            isPresented: $isShowingSignOutConfirmation
        ) {
            if let profileToSignOut, let publicKeyHex = profileToSignOut.publicKeyHex {
                Button(role: .destructive) {
                    viewModel.signOut(profileToSignOut)
                    self.profileToSignOut = nil
                } label: {
                    Text("Sign Out of \(viewModel.profileName(publicKeyHex: publicKeyHex))", comment: "Button to sign out of a profile from the device.")
                }
            }

            Button(role: .cancel) {
                profileToSignOut = nil
            } label: {
                Text("Cancel", comment: "Button to cancel out of dialog.")
            }
        } message: {
            Text("Your app settings will be deleted from this device. Your data on Nostr relays will not be affected.", comment: "Message to inform user about what will happen if they sign out.")
        }
    }
}

extension SettingsView {
    @Observable class ViewModel {
        let appState: AppState
        var profilePickerExpanded: Bool = false
        var isSignInViewPresented: Bool = false

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

        var appVersion: String {
            guard let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"],
                  let bundleVersion = Bundle.main.infoDictionary?["CFBundleVersion"]
            else {
                return String(localized: "Unknown", comment: "Text indicating that the version of the app that is running is unknown.")
            }

            return String(localized: "\(String(describing: shortVersion)) (\(String(describing: bundleVersion)))", comment: "Text indicating the version of the app that is running. The first argument is the version number, and the second argument is the build number.")
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
