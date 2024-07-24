//
//  ComingleApp.swift
//  Comingle
//
//  Created by Terry Yiu on 5/9/23.
//

import NostrSDK
import SwiftData
import SwiftUI

@main
struct ComingleApp: App {
    let container: ModelContainer

    @StateObject var appState = AppState()

    init() {
        do {
            container = try ModelContainer(for: AppSettings.self)
        } catch {
            fatalError("Failed to create ModelContainer for AppSettings.")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(modelContext: container.mainContext)
                .environmentObject(appState)
        }
        .modelContainer(container)
        .onChange(of: appState.appSettings?.activeProfile) { _, activeProfile in
            updateRelayPool(for: activeProfile)
        }
        .onChange(of: appState.appSettings?.activeProfile?.profileSettings?.relayPoolSettings?.relaySettingsList) { _, newRelaySettingsList in
            updateRelayPool(for: appState.appSettings?.activeProfile, relaySettingsList: newRelaySettingsList)
        }
    }

    private func updateRelayPool(for profile: Profile?, relaySettingsList: [RelaySettings]? = nil) {
        let relays = (relaySettingsList ?? profile?.profileSettings?.relayPoolSettings?.relaySettingsList ?? [])
            .compactMap { URL(string: $0.relayURLString) }
            .compactMap { try? Relay(url: $0) }
        let relaySet = Set(relays)

        let oldRelays = appState.relayPool.relays.subtracting(relaySet)
        let newRelays = relaySet.subtracting(appState.relayPool.relays)

        appState.relayPool.delegate = appState

        oldRelays.forEach {
            appState.relayPool.remove(relay: $0)
        }
        newRelays.forEach {
            appState.relayPool.add(relay: $0)
            appState.refresh(relay: $0)
        }
    }
}
