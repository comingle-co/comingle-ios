//
//  LoginView.swift
//  Confstr
//
//  Created by Terry Yiu on 6/18/23.
//

import SwiftUI
import Combine
import NostrSDK

struct LoginView: View {
    @ObservedObject var appState: AppState

    @State private var privateKey: String = ""
    @State private var primaryRelay: String = ""

    @State private var validKey: Bool = false
    @State private var validRelay: Bool = false

    static let defaultRelay = "wss://relay.confstr.com"

    private func relayFooter() -> AttributedString {
        var footer = AttributedString("Try \(LoginView.defaultRelay)")
        if let range = footer.range(of: LoginView.defaultRelay) {
            footer[range].underlineStyle = .single
            footer[range].foregroundColor = .blue
        }

        return footer
    }

    private func isValidRelay(address: String) -> Bool {
        guard let url = URL(string: address), let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }

        guard components.scheme == "wss" || components.scheme == "ws" else {
            return false
        }

        return true
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("Welcome to Confstr!")
                Text("Your go-to conference app powered by Nostr.")

                Form {
                    Section(
                        content: {
                            TextField("wss://relay.example.com", text: $primaryRelay)
                                .autocorrectionDisabled(false)
                                .textContentType(.password)
                                .textInputAutocapitalization(.never)
                                .onReceive(Just(primaryRelay)) { newValue in
                                    let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    primaryRelay = filtered

                                    if filtered.isEmpty {
                                        return
                                    }

                                    validRelay = isValidRelay(address: filtered)
                                }
                        },
                        header: {
                            Text("Primary Nostr Relay (Required)")
                        },
                        footer: {
                            Text(relayFooter())
                                .onTapGesture {
                                    primaryRelay = LoginView.defaultRelay
                                }
                        }
                    )

                    Section(
                        content: {
                            SecureField("nsec1...", text: $privateKey)
                                .autocorrectionDisabled(false)
                                .textContentType(.password)
                                .textInputAutocapitalization(.never)
                                .onReceive(Just(privateKey)) { newValue in
                                    let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                    privateKey = filtered

                                    let keypair = Keypair(nsec: filtered)
                                    validKey = (keypair != nil)
                                }
                        },
                        header: {
                            Text("Nostr Private Key (Optional)")
                        },
                        footer: {
                            Text("Leave blank if you are not logging in with an existing private key.")
                        }
                    )
                }

                Button("Guest Login") {
                    appState.keypair = nil
                    appState.relayUrlString = primaryRelay
                    appState.loginMode = .guest
                }
                .buttonStyle(.borderedProminent)
                .disabled(!validRelay)

                Button("Attendee Login") {
                    guard let keypair = Keypair(nsec: privateKey) else {
                        validKey = false
                        return
                    }
                    appState.keypair = keypair
                    appState.relayUrlString = primaryRelay
                    appState.loginMode = .attendee
                }
                .buttonStyle(.borderedProminent)
                .disabled(!validKey || !validRelay)

                Button("Organizer Login") {
                    guard let keypair = Keypair(nsec: privateKey) else {
                        validKey = false
                        return
                    }
                    appState.keypair = keypair
                    appState.relayUrlString = primaryRelay
                    appState.loginMode = .organizer
                }
                .buttonStyle(.borderedProminent)
                .disabled(!validKey || !validRelay)
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {

    static var appState = AppState()

    static var previews: some View {
        LoginView(appState: appState)
    }
}
