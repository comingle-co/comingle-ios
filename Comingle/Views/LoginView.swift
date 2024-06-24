//
//  LoginView.swift
//  Comingle
//
//  Created by Terry Yiu on 6/18/23.
//

import SwiftUI
import Combine
import NostrSDK

struct LoginView: View, RelayURLValidating {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorScheme) var colorScheme

    @State private var nostrIdentifier: String = "npub1yaul8k059377u9lsu67de7y637w4jtgeuwcmh5n7788l6xnlnrgs3tvjmf"
    @State private var primaryRelay: String = defaultRelay

    @State private var validKey: Bool = false
    @State private var validRelay: Bool = false

    static let defaultRelay = "wss://relay.primal.net"

    private func relayFooter() -> AttributedString {
        var footer = AttributedString(localized: .localizable.tryDefaultRelay(LoginView.defaultRelay))
        if let range = footer.range(of: LoginView.defaultRelay) {
            footer[range].underlineStyle = .single
            footer[range].foregroundColor = .blue
        }

        return footer
    }

    private func isValidRelay(address: String) -> Bool {
        do {
            _ = try validateRelayURLString(address)
            return true
        } catch {
            return false
        }
    }

    @MainActor
    private func login(forAttendee keypair: Keypair) {
        appState.keypair = keypair
        appState.publicKey = keypair.publicKey

        guard let relayURL = URL(string: primaryRelay) else {
            return
        }
        do {
            let relay = try Relay(url: relayURL)
            relay.delegate = appState
            appState.relay = relay
            relay.connect()
            appState.loginMode = .attendee
        } catch {
            return
        }
    }

    @MainActor
    private func login(forGuest publicKey: PublicKey?) {
        appState.keypair = nil
        appState.publicKey = publicKey

        guard let relayURL = URL(string: primaryRelay) else {
            return
        }
        do {
            let relay = try Relay(url: relayURL)
            relay.delegate = appState
            appState.relay = relay
            relay.connect()
            appState.loginMode = .guest
        } catch {
            return
        }
    }

    var body: some View {
        NavigationStack {
            Image("ComingleLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 300)

            Form {

                Section(
                    content: {
                        TextField(localized: .localizable.exampleRelay, text: $primaryRelay)
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

                                validRelay = isValidRelay(address: filtered)
                            }
                    },
                    header: {
                        Text(.localizable.primaryNostrRelayRequired)
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
                        SecureField("nsec1 or npub1...", text: $nostrIdentifier)
                            .autocorrectionDisabled(false)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .onReceive(Just(nostrIdentifier)) { newValue in
                                let filtered = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                                nostrIdentifier = filtered
                                validKey = Keypair(nsec: filtered) != nil || PublicKey(npub: filtered) != nil
                            }
                    },
                    header: {
                        Text(.localizable.nostrKeyHeader)
                    },
                    footer: {
                        Text(.localizable.nostrKeyFooter)
                    }
                )
            }

            Button(.localizable.loginModeGuest) {
                if let publicKey = PublicKey(npub: nostrIdentifier) {
                    login(forGuest: publicKey)
                } else {
                    validKey = false
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!validRelay)

            Button(.localizable.loginModeAttendee) {
                guard let keypair = Keypair(nsec: nostrIdentifier) else {
                    validKey = false
                    return
                }
                login(forAttendee: keypair)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!validKey || !validRelay)

//            Button(.localizable.loginModeOrganizer) {
//                guard let keypair = Keypair(nsec: privateKey) else {
//                    validKey = false
//                    return
//                }
//                login(keypair: keypair, loginMode: .organizer)
//            }
//            .buttonStyle(.borderedProminent)
//            .disabled(!validKey || !validRelay)
        }
    }
}

struct LoginView_Previews: PreviewProvider {

    static var appState = AppState()

    static var previews: some View {
        LoginView()
            .environmentObject(appState)
    }
}
