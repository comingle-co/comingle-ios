//
//  SettingsView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

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
                        Picker(.localizable.role, selection: $appState.loginMode) {

                            Text(LoginMode.guest.description)
                                .tag(LoginMode.guest.id)
                            Text(LoginMode.attendee.description)
                                .tag(LoginMode.attendee.id)
                            Text(LoginMode.organizer.description)
                                .tag(LoginMode.organizer.id)
                        }
                    },
                    header: {
                        Text(.localizable.role)
                    }
                )

                if appState.loginMode == .attendee || appState.loginMode == .organizer {
                    Section(
                        content: {
                            if let npub = appState.keypair?.publicKey.npub {
                                Text(npub)
                            } else {
                                Text(.localizable.settingsEnterPrivateKey)
                            }
                        },
                        header: {
                            Text(.localizable.settingsPublicKey)
                        }
                    )

                    Section(
                        content: {
                            TextField("nsec1...", text: $privateKey)
                                .autocorrectionDisabled(false)
                                .textContentType(.password)
                                .textInputAutocapitalization(.never)
                                .onReceive(Just(privateKey)) { newValue in
                                    let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard privateKey != newValue else {
                                        return
                                    }

                                    privateKey = filtered

                                    if let keypair = Keypair(nsec: filtered) {
                                        appState.keypair = keypair
                                    }
                                }
                        },
                        header: {
                            Text(.localizable.settingsPrivateKeyHeader)
                        }
                    )
                }

                Section(
                    content: {
                        HStack {
                            Text(.localizable.settingsRelayLabel)
                            Text(appState.relayUrlString ?? "")
                        }
                        HStack {
                            Text(.localizable.settingsRelayConnectionStatus)

                            if let relayState = appState.relay?.state {
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
                    appState.relayUrlString = nil
                    if let relay = appState.relay {
                        relay.disconnect()
                        appState.relay = nil
                    }
                    appState.loginMode = .none
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
        loginMode: .attendee,
        keypair: Keypair()
    )

    static var previews: some View {
        SettingsView()
            .environmentObject(appState)
    }
}
