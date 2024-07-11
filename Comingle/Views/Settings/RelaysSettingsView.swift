//
//  RelaysSettingsView.swift
//  Comingle
//
//  Created by Terry Yiu on 7/10/24.
//

import SwiftUI

struct RelaysSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        List {
            Section(
                content: {
                    if let relaySettings = appState.appSettings?.activeProfile?.profileSettings?.relaySettings {
                        let relayURLStrings = relaySettings.relayURLStrings
                        ForEach(relaySettings.relayURLStrings, id: \.self) { relayURLString in
                            Text(relayURLString)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        relaySettings.relayURLStrings = relayURLStrings.filter { $0 != relayURLString }
                                    } label: {
                                        Label(.localizable.delete, systemImage: "trash")
                                    }
                                }
                        }
                    }
                },
                header: {
                    Text(.localizable.settingsRelays)
                }
            )
        }
    }
}

#Preview {
    RelaysSettingsView()
}
