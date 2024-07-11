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
    @StateObject var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .modelContainer(
            for: [AppSettings.self]
        )
        .onChange(of: appState.appSettings?.activeProfile) { _, activeProfile in
            updateRelayPool(for: activeProfile)
        }
        .onChange(of: appState.appSettings?.activeProfile?.profileSettings?.relaySettings?.relayURLStrings) { _, newRelayURLStrings in
            updateRelayPool(for: appState.appSettings?.activeProfile, relayURLStrings: newRelayURLStrings)
        }
    }

    private func updateRelayPool(for profile: Profile?, relayURLStrings: [String]? = nil) {
        let relays = (relayURLStrings ?? profile?.profileSettings?.relaySettings?.relayURLStrings ?? [])
            .compactMap { URL(string: $0) }
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
