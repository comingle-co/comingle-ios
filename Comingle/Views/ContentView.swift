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

    @Environment(\.modelContext) var modelContext
    @State private var appSettings: AppSettings?
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationStack {
            VStack {
                TabView(selection: $appState.activeTab) {
                    if appState.publicKey != nil {
                        NavigationStack {
                            HomeView()
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

                    NavigationStack {
                        SettingsView()
                    }
                    .tabItem {
                        Label(.localizable.settings, systemImage: "gear")
                    }
                    .tag(HomeTabs.settings)
                }
            }
            .task {
                loadAppSettings()
            }
            .toolbar {
                if let publicKey = appState.publicKey {
                    NavigationLink(
                        destination: {
                            ProfileView(publicKeyHex: publicKey.hex)
                        },
                        label: {
                            ProfilePictureView(publicKeyHex: publicKey.hex)
                        }
                    )
                } else {
                    GuestProfilePictureView()
                        .onTapGesture {
                            appState.activeTab = .settings
                        }
                }
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
            appSettings = newAppSettings
        }

        appState.appSettings = appSettings
    }
}

struct ContentView_Previews: PreviewProvider {

    @State static var appState = AppState()

    static var previews: some View {
        ContentView()
            .environmentObject(appState)
            .modelContainer(for: [AppSettings.self])
    }
}
