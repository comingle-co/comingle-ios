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

    @State private var appState: AppState

    init() {
        NostrEventValueTransformer.register()
        do {
            container = try ModelContainer(for: AppSettings.self, PersistentNostrEvent.self)
            appState = AppState(modelContext: container.mainContext)
        } catch {
            fatalError("Failed to create ModelContainer for AppSettings and PersistentNostrEvent.")
        }

        loadAppSettings()
        loadProfiles()
        loadNostrEvents()
        appState.updateRelayPool()
        appState.refresh()
    }

    var body: some Scene {
        WindowGroup {
            ContentView(modelContext: container.mainContext)
                .environmentObject(appState)
        }
        .modelContainer(container)
    }

    @MainActor
    private func loadAppSettings() {
        let context = container.mainContext
        let request = FetchDescriptor<AppSettings>()
        let data = try? context.fetch(request)
        let appSettings: AppSettings
        if let existingAppSettings = data?.first {
            appSettings = existingAppSettings
        } else {
            let newAppSettings = AppSettings()
            context.insert(newAppSettings)
            do {
                try context.save()
                appSettings = newAppSettings
                appSettings.activeProfile?.profileSettings?.relayPoolSettings?.relaySettingsList.append(RelaySettings(relayURLString: AppState.defaultRelayURLString))
            } catch {
                fatalError("Unable to save initial AppSettings.")
            }
        }

        appState.appSettings = appSettings

        if appState.publicKey != nil {
            appState.activeTab = .following
        } else {
            appState.activeTab = .explore
        }
    }

    @MainActor
    private func loadProfiles() {
        let profileDescriptor = FetchDescriptor<Profile>()
        let profiles = (try? container.mainContext.fetch(profileDescriptor)) ?? []
        appState.profiles = profiles
    }

    @MainActor
    private func loadNostrEvents() {
        let descriptor = FetchDescriptor<PersistentNostrEvent>()
        let persistentNostrEvents = (try? container.mainContext.fetch(descriptor)) ?? []
        appState.loadPersistentNostrEvents(persistentNostrEvents)

        appState.refreshFollowedPubkeys()
    }
}
