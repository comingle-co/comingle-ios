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

    @State var selectedProfile: String?

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    content: {
                        if let appSettings = appState.appSettings {
                            ForEach(appSettings.profiles, id: \.self) { profile in
                                ProfileSmallView(publicKeyHex: profile.publicKeyHex)
                                    .tag(profile.publicKeyHex)
                                    .onTapGesture {
                                        appSettings.activeProfile = profile
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
                        }
                    },
                    header: {
                        Text(.localizable.profiles)
                    }
                )

                Section(
                    content: {

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
