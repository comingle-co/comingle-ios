//
//  ContentView.swift
//  Comingle
//
//  Created by Terry Yiu on 5/9/23.
//

import NostrSDK
import SwiftUI

struct ContentView: View {

    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView(selection: $appState.activeTab) {
            NavigationStack {
                HomeView()
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
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(destination: SettingsView()) {
                    Image(systemName: "gear")
                }
            }
        }
        .task {
            guard let relayURL = URL(string: AppState.defaultRelayURLString), let relay = try? Relay(url: relayURL) else {
                return
            }
            relay.delegate = appState
            appState.relay = relay
            relay.connect()
        }
    }
}

#Preview {
    ContentView()
}
