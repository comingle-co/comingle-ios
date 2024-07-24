//
//  ContentView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/9/23.
//

import Kingfisher
import NostrSDK
import SwiftData
import SwiftUI

struct ContentView: View {

    let modelContext: ModelContext
    @State private var appSettings: AppSettings?
    @EnvironmentObject var appState: AppState

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    var body: some View {
        NavigationStack {
            VStack {
                TabView(selection: $appState.activeTab) {
                    if appState.publicKey != nil {
                        NavigationStack {
                            HomeView(modelContext: modelContext, appState: appState)
                        }
                        .tabItem {
                            Label(.localizable.home, systemImage: "house")
                        }
                        .tag(HomeTabs.following)
                    }

                    NavigationStack {
                        EventListView(eventListType: .all)
                            .navigationTitle(.localizable.explore)
                    }
                    .tabItem {
                        Label(.localizable.explore, systemImage: "magnifyingglass")
                    }
                    .tag(HomeTabs.explore)
                }
            }
            .task {
                loadAppSettings()
                loadProfiles()
            }
            .toolbar {
                NavigationLink(
                    destination: {
                        SettingsView(modelContext: modelContext, appState: appState)
                    },
                    label: {
                        if let publicKey = appState.publicKey {
                            if appState.keypair != nil {
                                ProfilePictureView(publicKeyHex: publicKey.hex)
                            } else {
                                ProfilePictureView(publicKeyHex: publicKey.hex)
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
                    }
                )
            }
        }
    }

    private func loadAppSettings() {
        let request = FetchDescriptor<AppSettings>()
        let data = try? modelContext.fetch(request)
        if let existingAppSettings = data?.first {
            appSettings = existingAppSettings
        } else {
            let newAppSettings = AppSettings()
            modelContext.insert(newAppSettings)
            do {
                try modelContext.save()
                appSettings = newAppSettings
                appSettings?.activeProfile?.profileSettings?.relayPoolSettings?.relaySettingsList.append(RelaySettings(relayURLString: AppState.defaultRelayURLString))
            } catch {
                fatalError("Unable to save initial AppSettings.")
            }
        }

        appState.appSettings = appSettings
    }

    private func loadProfiles() {
        var profileDescriptor = FetchDescriptor<Profile>()
        var profiles = (try? modelContext.fetch(profileDescriptor)) ?? []
        appState.profiles = profiles
    }
}

//struct ContentView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        ContentView()
//            .environmentObject(appState)
//            .modelContainer(for: [AppSettings.self])
//    }
//}
