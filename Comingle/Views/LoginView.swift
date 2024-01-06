//
//  LoginView.swift
//  Comingle
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

    static let defaultRelay = "wss://relay.comingle.co"

    private func relayFooter() -> AttributedString {
        var footer = AttributedString(localized: .localizable.tryDefaultRelay(LoginView.defaultRelay))
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
                Text(.localizable.welcome)
                Text(.localizable.appDescription)

                Form {
                    Section(
                        content: {
                            TextField(localized: .localizable.exampleRelay, text: $primaryRelay)
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
                            Text(.localizable.privateKeyHeader)
                        },
                        footer: {
                            Text(.localizable.privateKeyFooter)
                        }
                    )
                }

                Button(.localizable.loginModeGuest) {
                    appState.keypair = nil
                    appState.relayUrlString = primaryRelay
                    appState.loginMode = .guest
                }
                .buttonStyle(.borderedProminent)
                .disabled(!validRelay)

                Button(.localizable.loginModeAttendee) {
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

                Button(.localizable.loginModeOrganizer) {
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
