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
    @State var privateKey: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    content: {
                        HStack {
                            Text(.localizable.settingsRelayLabel)
                            Text(appState.relayPool.relays.first?.url.absoluteString ?? "")
                        }
                        HStack {
                            Text(.localizable.settingsRelayConnectionStatus)

                            if let relayState = appState.relayPool.relays.first?.state {
                                switch relayState {
                                case .notConnected:
                                    Text(.localizable.settingsRelayNotConnected)
                                case .error(let error):
                                    Text(.localizable.settingsRelayConnectionError(error.localizedDescription))
                                case .connecting:
                                    Text(.localizable.settingsRelayConnecting)
                                case .connected:
                                    Text(.localizable.settingsRelayConnected)
                                }
                            } else {
                                Text(.localizable.settingsRelayNotConnected)
                            }
                        }
                    },
                    header: {
                        Text(.localizable.settingsRelayConnectionHeader)
                    }
                )
                Button(.localizable.signOut) {
                    appState.keypair = nil
                    appState.relayPool.disconnect()
                }
            }
        }
        .navigationTitle(.localizable.settings)
        .onAppear {
            self.privateKey = appState.keypair?.privateKey.nsec ?? ""
        }
    }
}

struct SettingsView_Previews: PreviewProvider {

    @State static var appState = AppState(
        keypair: Keypair()
    )

    static var previews: some View {
        SettingsView()
            .environmentObject(appState)
    }
}
