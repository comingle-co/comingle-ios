//
//  ContentView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/9/23.
//

import NostrSDK
import SwiftData
import SwiftUI

struct ContentView: View {

    @Environment(\.modelContext) var modelContext
    @State private var appSettings: AppSettings?

    @EnvironmentObject var appState: AppState

    var nonOptionalAppSettings: Binding<AppSettings> {
        Binding(
            get: {
                self.appSettings ?? AppSettings()
            },
            set: {
                self.appSettings = $0
            }
        )
    }

    var body: some View {
        TabView(selection: $appState.activeTab) {
            NavigationStack {
                HomeView(appSettings: nonOptionalAppSettings)
                    .environmentObject(appState)
            }
            .tabItem {
                Label(.localizable.home, systemImage: "house")
            }
            .tag(HomeTabs.following)

            NavigationStack {
                CalendarEventListView(showAllEvents: true)
                    .navigationTitle(.localizable.explore)
            }
            .tabItem {
                Label(.localizable.explore, systemImage: "magnifyingglass")
            }
            .tag(HomeTabs.explore)

            NavigationStack {
                SettingsView(appSettings: nonOptionalAppSettings)
            }
            .tabItem {
                Label(.localizable.settings, systemImage: "gear")
            }
            .tag(HomeTabs.settings)
        }
        .task {
            loadAppSettings()

            guard let relayURL = URL(string: AppState.defaultRelayURLString), let relay = try? Relay(url: relayURL) else {
                return
            }
            appState.relayPool.delegate = appState
            appState.relayPool.add(relay: relay)
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AppSettings.self])
}
