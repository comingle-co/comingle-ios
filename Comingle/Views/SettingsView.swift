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

    @ObservedObject var appState: AppState
    @State var privateKey: String

    init(appState: AppState) {
        self.appState = appState
        self.privateKey = appState.keypair?.privateKey.nsec ?? ""
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    content: {
                        Picker("Role", selection: $appState.loginMode) {

                            Text(LoginMode.guest.description)
                                .tag(LoginMode.guest.id)
                            Text(LoginMode.attendee.description)
                                .tag(LoginMode.attendee.id)
                            Text(LoginMode.organizer.description)
                                .tag(LoginMode.organizer.id)
                        }
                    },
                    header: {
                        Text("Role")
                    }
                )

                if appState.loginMode == .attendee || appState.loginMode == .organizer {
                    Section(
                        content: {
                            Text(appState.keypair?.publicKey.npub ?? "Enter a private key below")
                        },
                        header: {
                            Text("Public Key")
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
                            Text("Private Key")
                        }
                    )
                }

                Section(
                    content: {
                        HStack {
                            Text("Relay:")
                            Text(appState.relayUrlString ?? "")
                        }
                        HStack {
                            Text("Connection Status:")

                            if let relayState = appState.relay?.state {
                                switch relayState {
                                case .notConnected:
                                    Text("Not connected")
                                case .error(let error):
                                    Text("Error: \(error.localizedDescription)")
                                case .connecting:
                                    Text("Connecting...")
                                case .connected:
                                    Text("Connected")
                                }
                            } else {
                                Text("Not connected")
                            }
                        }
                    },
                    header: {
                        Text("Relay Connection")
                    }
                )
                Button("Sign Out") {
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
        .navigationTitle("Settings")
    }
}

struct SettingsView_Previews: PreviewProvider {

    @State static var appState = {
        let appState = AppState()
        appState.loginMode = .attendee
        appState.keypair = Keypair()

        return appState
    }

    static var previews: some View {
        SettingsView(appState: appState())
    }
}
