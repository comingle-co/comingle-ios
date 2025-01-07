//
//  SignInView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import Combine
import NostrSDK
import SwiftData
import SwiftUI

struct SignInView: View, RelayURLValidating {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject var appState: AppState

    @State private var nostrIdentifier: String = ""
    @State private var primaryRelay: String = ""

    @State private var validKey: Bool = false
    @State private var validatedRelayURL: URL?

    @State private var keypair: Keypair?
    @State private var publicKey: PublicKey?

    private func relayFooter() -> AttributedString {
        var footer = AttributedString(localized: "Try \(AppState.defaultRelayURLString). Note: authenticated relays are not yet supported.", comment: "Text prompting user to try connecting to the default relay and a note mentioning that authenticated relays are not yet supported.")
        if let range = footer.range(of: AppState.defaultRelayURLString) {
            footer[range].underlineStyle = .single
            footer[range].foregroundColor = .accent
        }

        return footer
    }

    private func isValidRelay(address: String) -> Bool {
        (try? validateRelayURLString(address)) != nil
    }

    @MainActor
    private func signIn() {
        guard let validatedRelayURL else {
            return
        }

        if let keypair {
            appState.signIn(keypair: keypair, relayURLs: [validatedRelayURL])
            dismiss()
        } else if let publicKey {
            appState.signIn(publicKey: publicKey, relayURLs: [validatedRelayURL])
            dismiss()
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    content: {
                        TextField(String(localized: "wss://relay.example.com", comment: "Example URL of a Nostr relay address."), text: $primaryRelay)
                            .autocorrectionDisabled(false)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onReceive(Just(primaryRelay)) { newValue in
                                let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                primaryRelay = filtered

                                if filtered.isEmpty {
                                    return
                                }

                                validatedRelayURL = try? validateRelayURLString(filtered)
                            }
                    },
                    header: {
                        Text("Primary Nostr Relay (Required)", comment: "Header text prompting required entry of the primary Nostr relay.")
                    },
                    footer: {
                        Text(relayFooter())
                            .onTapGesture {
                                primaryRelay = AppState.defaultRelayURLString
                            }
                    }
                )

                Section(
                    content: {
                        SecureField(String(localized: "Enter a Nostr public key or private key", comment: "Prompt asking user to enter in a Nostr key."), text: $nostrIdentifier)
                            .autocorrectionDisabled(false)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .onReceive(Just(nostrIdentifier)) { newValue in
                                let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                nostrIdentifier = filtered

                                if let keypair = Keypair(nsec: filtered) {
                                    self.keypair = keypair
                                    self.publicKey = keypair.publicKey
                                    validKey = true
                                } else if let publicKey = PublicKey(npub: filtered) {
                                    self.keypair = nil
                                    self.publicKey = publicKey
                                    validKey = true
                                } else {
                                    self.keypair = nil
                                    self.publicKey = nil
                                    validKey = false
                                }
                            }
                    },
                    header: {
                        Text("Nostr Key", comment: "Header text prompting optional entry of the user's private or public key.")
                    },
                    footer: {
                        if keypair != nil {
                            Text("You have entered a private key, which means you will be able to view, create, modify, and RSVP to events.", comment: "Footer text indicating what it means to have a private key entered.")
                        } else if publicKey != nil {
                            Text("You have entered a public key, which means you will be able to only view events.", comment: "Footer text indicating what it means to use a public key.")
                        }
                    }
                )
            }

            Button(String(localized: "Find Me on Nostr", comment: "Button to query data using the private or public key on Nostr relays.")) {
                signIn()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!validKey || validatedRelayURL == nil)
        }
        .onAppear {
            let credentialHandler = CredentialHandler(appState: appState)
            credentialHandler.checkCredentials()
        }
    }
}

//struct SignInView_Previews: PreviewProvider {
//
//    @State static var appState = AppState()
//
//    static var previews: some View {
//        SignInView()
//            .environmentObject(appState)
//    }
//}
