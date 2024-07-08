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
    @State private var primaryRelay: String = AppState.defaultRelayURLString

    @State private var validKey: Bool = false
    @State private var validRelay: Bool = false

    @State private var keypair: Keypair?
    @State private var publicKey: PublicKey?

    private func relayFooter() -> AttributedString {
        var footer = AttributedString(localized: .localizable.tryDefaultRelay(AppState.defaultRelayURLString))
        if let range = footer.range(of: AppState.defaultRelayURLString) {
            footer[range].underlineStyle = .single
            footer[range].foregroundColor = .blue
        }

        return footer
    }

    private func isValidRelay(address: String) -> Bool {
        (try? validateRelayURLString(address)) != nil
    }

    @MainActor
    private func login() {
        guard let appSettings = appState.appSettings, let publicKey else {
            return
        }

        if appSettings.profiles.first(where: { $0.publicKeyHex == publicKey.hex }) != nil {
            print("Found existing profile settings for \(publicKey.npub)")
        } else {
            print("Creating new profile settings for \(publicKey.npub)")
            let profile = Profile(publicKeyHex: publicKey.hex)
            appSettings.profiles.append(profile)
            appSettings.activeProfile = profile
        }

        appState.keypair = keypair

        guard let relayURL = URL(string: primaryRelay), let relay = try? Relay(url: relayURL) else {
            return
        }

        appState.relayPool.add(relay: relay)
        appState.refresh(publicKeyHex: publicKey.hex)
        appState.loginMode = .guest
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
                                primaryRelay = AppState.defaultRelayURLString
                            }
                    }
                )

                Section(
                    content: {
                        SecureField("npub or nsec...", text: $nostrIdentifier)
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
                        Text(.localizable.nostrKeyHeader)
                    },
                    footer: {
                        if keypair != nil {
                            Text(.localizable.nostrPrivateKeyFooter)
                        } else if publicKey != nil {
                            Text(.localizable.nostrPublicKeyFooter)
                        }
                    }
                )
            }

            Button(.localizable.findMeOnNostr) {
                login()
            }
            .buttonStyle(.borderedProminent)
            .disabled(!validKey || !validRelay)
        }
    }
}

struct LoginView_Previews: PreviewProvider {

    @State static var appSettings = AppSettings()

    static var previews: some View {
        LoginView()
    }
}
